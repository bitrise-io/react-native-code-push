import type CodePush from '../../typings/react-native-code-push';
import type { CodePushProviderProps, SyncOptions } from '../../typings/react-native-code-push';

// The automatic part of <CodePushProvider>: the launch step on mount and the checks on resume. It is React-free and
// gets everything from CodePush.js, so unit tests can drive it with fakes.

export interface AppLifecycleConfig extends Pick<CodePushProviderProps, 'checkFrequency' | 'onError'> {
  syncOptions: SyncOptions;
}

export interface AppLifecycleDeps {
  sync(options: SyncOptions): Promise<unknown>;
  notifyAppReady(): Promise<unknown>;
  appState: {
    addEventListener(type: 'change', listener: (state: string) => void): { remove(): void };
  };
  CheckFrequency: Pick<typeof CodePush.CheckFrequency, 'MANUAL' | 'ON_APP_RESUME'>;
}

/**
 * Runs the launch step and listens for resume checks. `getConfig` is read on each use, so prop changes apply to the
 * next resume check and to `onError`. Returns a function that removes the `AppState` listener.
 */
export function startAppLifecycle(deps: AppLifecycleDeps, getConfig: () => AppLifecycleConfig): () => void {
  async function attempt(operation: () => Promise<unknown>): Promise<void> {
    try {
      await operation();
    } catch (error) {
      getConfig().onError?.(error as Error);
    }
  }

  const runSync = () => attempt(() => deps.sync(getConfig().syncOptions));
  const runNotifyAppReady = () => attempt(deps.notifyAppReady);

  if (getConfig().checkFrequency === deps.CheckFrequency.MANUAL) {
    runNotifyAppReady();
  } else {
    runSync();
  }

  // Always subscribe, so a later change of checkFrequency to ON_APP_RESUME also works.
  const subscription = deps.appState.addEventListener('change', (state) => {
    if (state !== 'active') {
      return;
    }
    if (getConfig().checkFrequency === deps.CheckFrequency.ON_APP_RESUME) {
      runSync();
    } else {
      // Retries a failed notifyAppReady(), so the update is not rolled back on the next start. CodePush.js keeps a
      // successful result, so after a success this does nothing.
      runNotifyAppReady();
    }
  });

  return () => subscription.remove();
}
