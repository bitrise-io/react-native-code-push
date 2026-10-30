import * as assert from 'assert';

import type { SyncOptions } from '../../../typings/react-native-code-push';
import { AppLifecycleConfig, AppLifecycleDeps, startAppLifecycle } from '../app-lifecycle';

// The numbers are the public CheckFrequency values, but the controller only compares them with the injected ones.
const CheckFrequency = {
  ON_APP_START: 0,
  ON_APP_RESUME: 1,
  MANUAL: 2,
} as unknown as AppLifecycleDeps['CheckFrequency'] & {
  ON_APP_START: AppLifecycleConfig['checkFrequency'];
};

class FakeAppState {
  private listeners = new Set<(state: string) => void>();

  get listenerCount(): number {
    return this.listeners.size;
  }

  addEventListener(_type: 'change', listener: (state: string) => void): { remove(): void } {
    this.listeners.add(listener);
    return { remove: () => this.listeners.delete(listener) };
  }

  emit(state: string): void {
    this.listeners.forEach((listener) => listener(state));
  }
}

function flushPromises(): Promise<void> {
  return new Promise((resolve) => setImmediate(resolve));
}

describe('startAppLifecycle', () => {
  let appState: FakeAppState;
  let syncCalls: SyncOptions[];
  let notifyAppReadyCalls: number;
  let syncImpl: () => Promise<unknown>;
  let notifyAppReadyImpl: () => Promise<unknown>;
  let errors: Error[];
  const onError = (error: Error): void => {
    errors.push(error);
  };

  function start(getConfig: () => Partial<AppLifecycleConfig>): () => void {
    return startAppLifecycle(
      {
        sync: (options) => {
          syncCalls.push(options);
          return syncImpl();
        },
        notifyAppReady: () => {
          notifyAppReadyCalls++;
          return notifyAppReadyImpl();
        },
        appState,
        CheckFrequency,
      },
      () => ({ syncOptions: {}, ...getConfig() }),
    );
  }

  beforeEach(() => {
    appState = new FakeAppState();
    syncCalls = [];
    notifyAppReadyCalls = 0;
    syncImpl = async () => undefined;
    notifyAppReadyImpl = async () => undefined;
    errors = [];
  });

  it('MANUAL calls only notifyAppReady', async () => {
    const stop = start(() => ({ checkFrequency: CheckFrequency.MANUAL }));
    await flushPromises();

    assert.strictEqual(notifyAppReadyCalls, 1);
    assert.strictEqual(syncCalls.length, 0);
    stop();
  });

  it('ON_APP_START calls sync once, and a resume only calls notifyAppReady', async () => {
    const stop = start(() => ({ checkFrequency: CheckFrequency.ON_APP_START }));
    await flushPromises();
    assert.strictEqual(syncCalls.length, 1);

    appState.emit('active');
    await flushPromises();

    assert.strictEqual(syncCalls.length, 1);
    assert.strictEqual(notifyAppReadyCalls, 1);
    stop();
  });

  it('without checkFrequency, behaves as ON_APP_START', async () => {
    const stop = start(() => ({}));
    await flushPromises();
    appState.emit('active');
    await flushPromises();

    assert.strictEqual(syncCalls.length, 1);
    assert.strictEqual(notifyAppReadyCalls, 1);
    stop();
  });

  it('ON_APP_RESUME checks again when the app becomes active, not on other state changes', async () => {
    const stop = start(() => ({ checkFrequency: CheckFrequency.ON_APP_RESUME }));
    await flushPromises();
    appState.emit('background');
    appState.emit('inactive');
    await flushPromises();
    assert.strictEqual(syncCalls.length, 1);

    appState.emit('active');
    await flushPromises();
    assert.strictEqual(syncCalls.length, 2);
    stop();
  });

  it('stop removes the listener, so a StrictMode mount, stop, mount leaves one', async () => {
    const config = { checkFrequency: CheckFrequency.ON_APP_RESUME };

    const stop1 = start(() => config);
    stop1();
    const stop2 = start(() => config);
    assert.strictEqual(appState.listenerCount, 1);

    stop2();
    assert.strictEqual(appState.listenerCount, 0);

    await flushPromises();
    appState.emit('active');
    await flushPromises();
    assert.strictEqual(syncCalls.length, 2, 'only the two launch syncs, no resume check after stop');
  });

  it('resume checks and onError use the latest config', async () => {
    const firstErrors: Error[] = [];
    let config: Partial<AppLifecycleConfig> = {
      checkFrequency: CheckFrequency.ON_APP_RESUME,
      syncOptions: { deploymentKey: 'production' },
      onError: (error) => firstErrors.push(error),
    };
    const stop = start(() => config);
    await flushPromises();

    config = { ...config, syncOptions: { deploymentKey: 'staging' }, onError };
    syncImpl = async () => {
      throw new Error('network');
    };
    appState.emit('active');
    await flushPromises();

    assert.strictEqual(syncCalls[0].deploymentKey, 'production');
    assert.strictEqual(syncCalls[1].deploymentKey, 'staging');
    assert.deepStrictEqual(firstErrors, []);
    assert.deepStrictEqual(
      errors.map((e) => e.message),
      ['network'],
    );
    stop();
  });

  it('a resume does not check while checkFrequency is not ON_APP_RESUME, and checks after it changes', async () => {
    let config: Partial<AppLifecycleConfig> = { checkFrequency: CheckFrequency.MANUAL };
    const stop = start(() => config);
    await flushPromises();

    appState.emit('active');
    await flushPromises();
    assert.strictEqual(syncCalls.length, 0);

    config = { checkFrequency: CheckFrequency.ON_APP_RESUME };
    appState.emit('active');
    await flushPromises();
    assert.strictEqual(syncCalls.length, 1);
    stop();
  });

  it('passes the sync options to sync', async () => {
    const stop = start(() => ({ syncOptions: { installMode: 2, minimumBackgroundDuration: 60 } }));
    await flushPromises();

    assert.deepStrictEqual(syncCalls[0], { installMode: 2, minimumBackgroundDuration: 60 });
    stop();
  });

  it('reports a failed sync to onError', async () => {
    syncImpl = async () => {
      throw new Error('check failed');
    };
    const stop = start(() => ({ onError }));
    await flushPromises();

    assert.deepStrictEqual(
      errors.map((e) => e.message),
      ['check failed'],
    );
    stop();
  });

  it('MANUAL reports a failed notifyAppReady to onError', async () => {
    notifyAppReadyImpl = async () => {
      throw new Error('native');
    };
    const stop = start(() => ({ checkFrequency: CheckFrequency.MANUAL, onError }));
    await flushPromises();

    assert.deepStrictEqual(
      errors.map((e) => e.message),
      ['native'],
    );
    stop();
  });

  it('retries a failed notifyAppReady on resume, without checking for an update', async () => {
    notifyAppReadyImpl = async () => {
      throw new Error('native');
    };
    const stop = start(() => ({ checkFrequency: CheckFrequency.MANUAL, onError }));
    await flushPromises();

    notifyAppReadyImpl = async () => undefined;
    appState.emit('active');
    await flushPromises();

    assert.strictEqual(notifyAppReadyCalls, 2);
    assert.strictEqual(syncCalls.length, 0);
    assert.strictEqual(errors.length, 1);
    stop();
  });
});
