import * as assert from 'assert';

import type { LocalPackage } from '../../../typings/react-native-code-push';
import { trackDownload, trackInstall } from '../track-update';
import type { UpdateEvent } from '../update-state';

function recorder() {
  const events: UpdateEvent[] = [];
  return { events, store: { dispatch: (event: UpdateEvent) => events.push(event) } };
}

describe('trackDownload', () => {
  it('reports a download that completes, and returns its result', async () => {
    const { events, store } = recorder();

    assert.strictEqual(await trackDownload(store, async () => 'package'), 'package');
    assert.deepStrictEqual(
      events.map((e) => e.type),
      ['downloadStarted', 'downloadCompleted'],
    );
  });

  it('reports a download that fails, and rethrows its error', async () => {
    const { events, store } = recorder();
    const error = new Error('network');

    await assert.rejects(
      trackDownload(store, () => Promise.reject(error)),
      error,
    );
    assert.deepStrictEqual(events, [{ type: 'downloadStarted' }, { type: 'downloadFailed', error }]);
  });
});

describe('trackInstall', () => {
  const localPackage = {
    label: 'v2',
    packageHash: 'hash',
    isPending: false,
    install: () => Promise.resolve(),
  } as unknown as LocalPackage;

  it('reports a pending copy of the package, without its methods', async () => {
    const { events, store } = recorder();

    await trackInstall(store, localPackage, () => Promise.resolve());

    assert.deepStrictEqual(events, [
      { type: 'updateInstalled', update: { label: 'v2', packageHash: 'hash', isPending: true } },
    ]);
  });

  it('reports a failed install, and rethrows its error', async () => {
    const { events, store } = recorder();
    const error = new Error('disk');

    await assert.rejects(
      trackInstall(store, localPackage, () => Promise.reject(error)),
      error,
    );
    assert.deepStrictEqual(events, [{ type: 'installFailed', error }]);
  });
});
