import type { CodePushState, IncompatibleUpdate, RemotePackage } from '../../typings/react-native-code-push';

export type UpdateEvent =
  | { type: 'checkStarted' }
  | { type: 'checkCompleted'; update: RemotePackage | null; incompatibleUpdate?: IncompatibleUpdate }
  | { type: 'checkFailed'; error: Error }
  | { type: 'updateInstalled'; packageHash: string };

export interface StoreState {
  /** A button check can overlap a resume sync, so `isChecking` stays true until all end. */
  runningChecks: number;
  snapshot: CodePushState;
}

export const initialState: StoreState = {
  runningChecks: 0,
  snapshot: {
    isChecking: false,
    isUpdateAvailable: false,
  },
};

export function reduce(state: StoreState, event: UpdateEvent): StoreState {
  switch (event.type) {
    case 'checkStarted':
      // The result of the previous check stays until this one completes.
      return next(state, state.runningChecks + 1, { checkError: undefined });
    case 'checkCompleted': {
      // sync() skips a previously rolled-back update by default, so it does not count as available.
      const update = event.update && !event.update.failedInstall ? event.update : undefined;
      return next(state, state.runningChecks - 1, {
        isUpdateAvailable: !!update,
        availableUpdate: update,
        incompatibleUpdate: event.incompatibleUpdate,
        checkError: undefined,
      });
    }
    case 'checkFailed':
      return next(state, state.runningChecks - 1, { checkError: event.error });
    case 'updateInstalled':
      // Only the update it installed: a newer check may have found another one meanwhile.
      if (state.snapshot.availableUpdate?.packageHash !== event.packageHash) {
        return state;
      }
      return next(state, state.runningChecks, { isUpdateAvailable: false, availableUpdate: undefined });
  }
}

function next(state: StoreState, runningChecks: number, changes: Partial<CodePushState>): StoreState {
  return { runningChecks, snapshot: updateSnapshot(state.snapshot, { ...changes, isChecking: runningChecks > 0 }) };
}

/** Keeps the snapshot identity when no value changes, so subscribers are not notified. */
function updateSnapshot(snapshot: CodePushState, changes: Partial<CodePushState>): CodePushState {
  const changed = (Object.keys(changes) as Array<keyof CodePushState>).some((key) => changes[key] !== snapshot[key]);
  return changed ? { ...snapshot, ...changes } : snapshot;
}
