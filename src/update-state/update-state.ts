import type {
  CodePushState,
  DownloadProgress,
  IncompatibleUpdate,
  RemotePackage,
} from '../../typings/react-native-code-push';

export type PendingUpdate = NonNullable<CodePushState['pendingUpdate']>;

export type UpdateEvent =
  | { type: 'checkStarted' }
  | { type: 'checkCompleted'; update: RemotePackage | null; incompatibleUpdate?: IncompatibleUpdate }
  | { type: 'checkFailed'; error: Error }
  | { type: 'downloadStarted' }
  | { type: 'downloadProgressed'; progress: DownloadProgress }
  | { type: 'downloadCompleted' }
  | { type: 'downloadFailed'; error: Error }
  | { type: 'installFailed'; error: Error }
  | { type: 'updateInstalled'; update: PendingUpdate }
  | { type: 'updatesCleared' };

export interface StoreState {
  /** A button check can overlap a resume sync, so `isChecking` stays true until all end. */
  runningChecks: number;
  /** sync() runs one download at a time, but `download()` of a RemotePackage can overlap it. */
  runningDownloads: number;
  snapshot: CodePushState;
  /**
   * Outside the snapshot, because it changes up to once per frame. Only the components that read it with
   * useDownloadProgress() re-render that often.
   */
  downloadProgress?: DownloadProgress;
}

export const initialState: StoreState = {
  runningChecks: 0,
  runningDownloads: 0,
  snapshot: {
    isChecking: false,
    isUpdateAvailable: false,
    isDownloading: false,
  },
};

export function reduce(state: StoreState, event: UpdateEvent): StoreState {
  switch (event.type) {
    case 'checkStarted':
      // The result of the previous check stays until this one completes.
      return next({ ...state, runningChecks: state.runningChecks + 1 }, { checkError: undefined });
    case 'checkCompleted': {
      // sync() skips a previously rolled-back update by default, so it does not count as available.
      const update = event.update && !event.update.failedInstall ? event.update : undefined;
      return next(
        { ...state, runningChecks: state.runningChecks - 1 },
        {
          isUpdateAvailable: !!update,
          availableUpdate: update,
          incompatibleUpdate: event.incompatibleUpdate,
          checkError: undefined,
        },
      );
    }
    case 'checkFailed':
      return next({ ...state, runningChecks: state.runningChecks - 1 }, { checkError: event.error });
    case 'downloadStarted':
      // A new attempt clears the errors of the previous one.
      return next(
        { ...state, runningDownloads: state.runningDownloads + 1, downloadProgress: undefined },
        { installError: undefined },
      );
    case 'downloadProgressed':
      return { ...state, downloadProgress: event.progress };
    case 'downloadCompleted':
      return next({ ...state, runningDownloads: state.runningDownloads - 1 }, {});
    case 'downloadFailed':
      return next(
        { ...state, runningDownloads: state.runningDownloads - 1, downloadProgress: undefined },
        { installError: event.error },
      );
    case 'installFailed':
      return next(state, { installError: event.error });
    case 'updateInstalled': {
      const changes: Partial<CodePushState> = { pendingUpdate: event.update, installError: undefined };
      // Only the update it installed: a newer check may have found another one meanwhile.
      if (state.snapshot.availableUpdate?.packageHash === event.update.packageHash) {
        changes.isUpdateAvailable = false;
        changes.availableUpdate = undefined;
      }
      return next(state, changes);
    }
    case 'updatesCleared':
      return next(state, { pendingUpdate: undefined });
  }
}

function next(state: StoreState, changes: Partial<CodePushState>): StoreState {
  return {
    ...state,
    snapshot: updateSnapshot(state.snapshot, {
      ...changes,
      isChecking: state.runningChecks > 0,
      isDownloading: state.runningDownloads > 0,
    }),
  };
}

/** Keeps the snapshot identity when no value changes, so subscribers are not notified. */
function updateSnapshot(snapshot: CodePushState, changes: Partial<CodePushState>): CodePushState {
  const changed = (Object.keys(changes) as Array<keyof CodePushState>).some((key) => changes[key] !== snapshot[key]);
  return changed ? { ...snapshot, ...changes } : snapshot;
}
