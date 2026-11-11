import * as assert from 'assert';

import { createUpdateStore } from '../update-store';

describe('createUpdateStore', () => {
  it('notifies subscribers of each change, until they unsubscribe', () => {
    const store = createUpdateStore();
    let calls = 0;
    const unsubscribe = store.subscribe(() => calls++);

    store.dispatch({ type: 'checkStarted' });
    assert.strictEqual(calls, 1);

    unsubscribe();
    store.dispatch({ type: 'checkCompleted', update: null });
    assert.strictEqual(calls, 1);
    assert.strictEqual(store.getSnapshot().isChecking, false);
  });

  it('changes the snapshot identity only when the snapshot changes', () => {
    const store = createUpdateStore();
    let calls = 0;
    store.subscribe(() => calls++);
    const initial = store.getSnapshot();

    store.dispatch({ type: 'checkStarted' });
    const checking = store.getSnapshot();
    assert.notStrictEqual(checking, initial);
    assert.strictEqual(store.getSnapshot(), checking, 'the same object until the next change');

    // A second overlapping check only changes the internal count.
    store.dispatch({ type: 'checkStarted' });
    assert.strictEqual(store.getSnapshot(), checking);
    assert.strictEqual(calls, 1);

    store.dispatch({ type: 'checkCompleted', update: null });
    assert.strictEqual(store.getSnapshot(), checking, 'still checking: one check runs');
    store.dispatch({ type: 'checkCompleted', update: null });
    assert.strictEqual(store.getSnapshot().isChecking, false);
    assert.strictEqual(calls, 2);
  });

  it('works with unbound functions, as useSyncExternalStore calls them', () => {
    const { getSnapshot, subscribe, dispatch } = createUpdateStore();
    let calls = 0;
    subscribe(() => calls++);

    dispatch({ type: 'checkStarted' });
    assert.strictEqual(getSnapshot().isChecking, true);
    assert.strictEqual(calls, 1);
  });

  it('notifies every subscriber when one unsubscribes during the notification', () => {
    const store = createUpdateStore();
    const calls: string[] = [];
    const unsubscribeFirst = store.subscribe(() => {
      calls.push('first');
      unsubscribeFirst();
    });
    store.subscribe(() => calls.push('second'));

    store.dispatch({ type: 'checkStarted' });
    assert.deepStrictEqual(calls, ['first', 'second']);
  });

  it('keeps a separate state for each store', () => {
    const first = createUpdateStore();
    const second = createUpdateStore();

    first.dispatch({ type: 'checkStarted' });
    assert.strictEqual(second.getSnapshot().isChecking, false);
  });

  it('notifies subscribers of download progress, without changing the snapshot', () => {
    const store = createUpdateStore();
    store.dispatch({ type: 'downloadStarted' });
    let calls = 0;
    store.subscribe(() => calls++);
    const snapshot = store.getSnapshot();
    const progress = { receivedBytes: 1, totalBytes: 2 };

    store.dispatch({ type: 'downloadProgressed', progress });

    assert.strictEqual(calls, 1);
    assert.strictEqual(store.getDownloadProgress(), progress);
    assert.strictEqual(store.getSnapshot(), snapshot);
  });
});
