import * as assert from 'assert';

import type { RemotePackage } from '../../../typings/react-native-code-push';
import { initialState, PendingUpdate, reduce, StoreState, UpdateEvent } from '../update-state';

function reduceAll(events: UpdateEvent[], state: StoreState = initialState): StoreState {
  return events.reduce(reduce, state);
}

const update = {
  label: 'v2',
  packageHash: 'hash',
  failedInstall: false,
} as RemotePackage;
const installed = {
  label: 'v2',
  packageHash: 'hash',
  isPending: true,
} as PendingUpdate;
const started: UpdateEvent = { type: 'checkStarted' };
const downloadStarted: UpdateEvent = { type: 'downloadStarted' };

describe('reduce', () => {
  it('starts idle, with no update, no download and no error', () => {
    assert.deepStrictEqual(initialState, {
      runningChecks: 0,
      runningDownloads: 0,
      snapshot: {
        isChecking: false,
        isUpdateAvailable: false,
        isDownloading: false,
      },
    });
  });

  it('checkStarted sets isChecking', () => {
    const { snapshot } = reduce(initialState, started);

    assert.strictEqual(snapshot.isChecking, true);
    assert.strictEqual(snapshot.isUpdateAvailable, false);
  });

  it('a check that returns an update makes it available', () => {
    const { snapshot } = reduceAll([started, { type: 'checkCompleted', update }]);

    assert.strictEqual(snapshot.isChecking, false);
    assert.strictEqual(snapshot.isUpdateAvailable, true);
    assert.strictEqual(snapshot.availableUpdate, update);
    assert.strictEqual(snapshot.checkError, undefined);
  });

  it('a check that finds no update clears the update of the previous check', () => {
    const { snapshot } = reduceAll([
      started,
      { type: 'checkCompleted', update },
      started,
      { type: 'checkCompleted', update: null },
    ]);

    assert.strictEqual(snapshot.isChecking, false);
    assert.strictEqual(snapshot.isUpdateAvailable, false);
    assert.strictEqual(snapshot.availableUpdate, undefined);
  });

  it('an update that failed to install before is not available, as sync() ignores it', () => {
    const { snapshot } = reduceAll([started, { type: 'checkCompleted', update: { ...update, failedInstall: true } }]);

    assert.strictEqual(snapshot.isUpdateAvailable, false);
    assert.strictEqual(snapshot.availableUpdate, undefined);
  });

  it('a check that finds an incompatible release sets incompatibleUpdate, and the next check clears it', () => {
    const incompatibleUpdate = { targetBinaryVersion: '^2.0.0' };
    const found = reduceAll([started, { type: 'checkCompleted', update: null, incompatibleUpdate }]);

    assert.strictEqual(found.snapshot.incompatibleUpdate, incompatibleUpdate);
    assert.strictEqual(found.snapshot.isUpdateAvailable, false);

    const cleared = reduceAll([started, { type: 'checkCompleted', update: null }], found);
    assert.strictEqual(cleared.snapshot.incompatibleUpdate, undefined);
  });

  it('a failed check keeps incompatibleUpdate', () => {
    const incompatibleUpdate = { targetBinaryVersion: '^2.0.0' };
    const { snapshot } = reduceAll([
      started,
      { type: 'checkCompleted', update: null, incompatibleUpdate },
      started,
      { type: 'checkFailed', error: new Error('network') },
    ]);

    assert.strictEqual(snapshot.incompatibleUpdate, incompatibleUpdate);
  });

  it('keeps the update of the previous check while a new check runs', () => {
    const { snapshot } = reduceAll([started, { type: 'checkCompleted', update }, started]);

    assert.strictEqual(snapshot.isChecking, true);
    assert.strictEqual(snapshot.isUpdateAvailable, true);
    assert.strictEqual(snapshot.availableUpdate, update);
  });

  it('checkFailed clears isChecking and sets checkError', () => {
    const error = new Error('network');
    const { snapshot } = reduceAll([started, { type: 'checkFailed', error }]);

    assert.strictEqual(snapshot.isChecking, false);
    assert.strictEqual(snapshot.checkError, error);
  });

  it('a new check clears checkError', () => {
    const failed = reduceAll([started, { type: 'checkFailed', error: new Error('network') }]);

    assert.strictEqual(reduce(failed, started).snapshot.checkError, undefined);
    assert.strictEqual(reduceAll([started, { type: 'checkCompleted', update }], failed).snapshot.checkError, undefined);
  });

  it('isChecking stays true until every overlapping check ends', () => {
    const twoRunning = reduceAll([started, started]);
    assert.strictEqual(twoRunning.runningChecks, 2);
    assert.strictEqual(twoRunning.snapshot.isChecking, true);

    const oneRunning = reduce(twoRunning, { type: 'checkCompleted', update });
    assert.strictEqual(oneRunning.snapshot.isChecking, true);
    assert.strictEqual(oneRunning.snapshot.availableUpdate, update, 'the result of the first check shows');

    const error = new Error('network');
    const noneRunning = reduce(oneRunning, { type: 'checkFailed', error });
    assert.strictEqual(noneRunning.runningChecks, 0);
    assert.strictEqual(noneRunning.snapshot.isChecking, false);
    assert.strictEqual(noneRunning.snapshot.checkError, error);
  });

  it('a second overlapping check changes only the internal count, not the snapshot', () => {
    const one = reduce(initialState, started);
    const two = reduce(one, started);

    assert.notStrictEqual(two, one);
    assert.strictEqual(two.snapshot, one.snapshot);
  });

  it('installing the available update clears it', () => {
    const { snapshot } = reduceAll([
      started,
      { type: 'checkCompleted', update },
      { type: 'updateInstalled', update: installed },
    ]);

    assert.strictEqual(snapshot.isUpdateAvailable, false);
    assert.strictEqual(snapshot.availableUpdate, undefined);
  });

  it('installing another update keeps the available one, and makes the installed one pending', () => {
    const other = { ...installed, packageHash: 'other' };
    const { snapshot } = reduceAll([
      started,
      { type: 'checkCompleted', update },
      { type: 'updateInstalled', update: other },
    ]);

    assert.strictEqual(snapshot.availableUpdate, update);
    assert.strictEqual(snapshot.pendingUpdate, other);
  });

  it('does not change the state it is given', () => {
    const before = JSON.parse(JSON.stringify(initialState));
    reduceAll([started, { type: 'checkCompleted', update }]);

    assert.deepStrictEqual(initialState, before);
  });

  describe('download', () => {
    it('downloadStarted sets isDownloading, and downloadCompleted clears it', () => {
      const downloading = reduce(initialState, downloadStarted);
      assert.strictEqual(downloading.snapshot.isDownloading, true);

      const done = reduce(downloading, { type: 'downloadCompleted' });
      assert.strictEqual(done.snapshot.isDownloading, false);
      assert.strictEqual(done.snapshot.installError, undefined);
    });

    it('downloadFailed clears isDownloading and sets installError, and keeps the available update', () => {
      const error = new Error('network');
      const { snapshot } = reduceAll([
        started,
        { type: 'checkCompleted', update },
        downloadStarted,
        { type: 'downloadFailed', error },
      ]);

      assert.strictEqual(snapshot.isDownloading, false);
      assert.strictEqual(snapshot.installError, error);
      assert.strictEqual(snapshot.availableUpdate, update, 'so the user can retry');
    });

    it('a new download clears installError, whether the download or the install failed', () => {
      const failures: UpdateEvent[] = [
        { type: 'downloadFailed', error: new Error('network') },
        { type: 'installFailed', error: new Error('disk') },
      ];
      for (const failure of failures) {
        const failed = reduceAll([downloadStarted, failure]);
        assert.notStrictEqual(failed.snapshot.installError, undefined);
        assert.strictEqual(reduce(failed, downloadStarted).snapshot.installError, undefined);
      }
    });

    it('a new check keeps installError', () => {
      const error = new Error('network');
      const { snapshot } = reduceAll([
        downloadStarted,
        { type: 'downloadFailed', error },
        started,
        { type: 'checkCompleted', update },
      ]);

      assert.strictEqual(snapshot.installError, error);
    });

    it('isDownloading stays true until every overlapping download ends', () => {
      const two = reduceAll([downloadStarted, downloadStarted]);
      assert.strictEqual(two.runningDownloads, 2);

      const one = reduce(two, { type: 'downloadCompleted' });
      assert.strictEqual(one.snapshot.isDownloading, true);

      const none = reduce(one, {
        type: 'downloadFailed',
        error: new Error('network'),
      });
      assert.strictEqual(none.snapshot.isDownloading, false);
    });

    it('progress changes only downloadProgress, not the snapshot', () => {
      const downloading = reduce(initialState, downloadStarted);
      const progress = { receivedBytes: 10, totalBytes: 100 };
      const progressed = reduce(downloading, {
        type: 'downloadProgressed',
        progress,
      });

      assert.strictEqual(progressed.downloadProgress, progress);
      assert.strictEqual(progressed.snapshot, downloading.snapshot);
    });

    it('a new or failed download clears the progress, and a completed one keeps it at its last value', () => {
      const progress = { receivedBytes: 100, totalBytes: 100 };
      const progressed = reduceAll([downloadStarted, { type: 'downloadProgressed', progress }]);

      assert.strictEqual(reduce(progressed, downloadStarted).downloadProgress, undefined);
      assert.strictEqual(
        reduce(progressed, {
          type: 'downloadFailed',
          error: new Error('network'),
        }).downloadProgress,
        undefined,
      );
      assert.strictEqual(reduce(progressed, { type: 'downloadCompleted' }).downloadProgress, progress);
    });
  });

  describe('install', () => {
    it('installFailed sets installError, and a successful install clears it', () => {
      const error = new Error('disk');
      const failed = reduce(initialState, { type: 'installFailed', error });
      assert.strictEqual(failed.snapshot.installError, error);

      assert.strictEqual(
        reduce(failed, { type: 'updateInstalled', update: installed }).snapshot.installError,
        undefined,
      );
    });

    it('an installed update is pending', () => {
      const { snapshot } = reduce(initialState, {
        type: 'updateInstalled',
        update: installed,
      });

      assert.strictEqual(snapshot.pendingUpdate, installed);
    });

    it('a check keeps the pending update, as only a restart applies it', () => {
      const { snapshot } = reduceAll([
        { type: 'updateInstalled', update: installed },
        started,
        { type: 'checkCompleted', update: null },
      ]);

      assert.strictEqual(snapshot.pendingUpdate, installed);
    });

    it('clearing the updates removes the pending update', () => {
      const { snapshot } = reduceAll([{ type: 'updateInstalled', update: installed }, { type: 'updatesCleared' }]);

      assert.strictEqual(snapshot.pendingUpdate, undefined);
    });
  });
});
