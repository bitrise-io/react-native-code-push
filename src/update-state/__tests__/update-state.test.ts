import * as assert from 'assert';

import type { RemotePackage } from '../../../typings/react-native-code-push';
import { initialState, reduce, StoreState, UpdateEvent } from '../update-state';

function reduceAll(events: UpdateEvent[], state: StoreState = initialState): StoreState {
  return events.reduce(reduce, state);
}

const update = { label: 'v2', packageHash: 'hash', failedInstall: false } as RemotePackage;
const started: UpdateEvent = { type: 'checkStarted' };

describe('reduce', () => {
  it('starts idle, with no update and no error', () => {
    assert.deepStrictEqual(initialState, {
      runningChecks: 0,
      snapshot: { isChecking: false, isUpdateAvailable: false },
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
      { type: 'updateInstalled', packageHash: 'hash' },
    ]);

    assert.strictEqual(snapshot.isUpdateAvailable, false);
    assert.strictEqual(snapshot.availableUpdate, undefined);
  });

  it('installing another update keeps the available one', () => {
    const found = reduceAll([started, { type: 'checkCompleted', update }]);

    assert.strictEqual(reduce(found, { type: 'updateInstalled', packageHash: 'other' }), found);
  });

  it('does not change the state it is given', () => {
    const before = JSON.parse(JSON.stringify(initialState));
    reduceAll([started, { type: 'checkCompleted', update }]);

    assert.deepStrictEqual(initialState, before);
  });
});
