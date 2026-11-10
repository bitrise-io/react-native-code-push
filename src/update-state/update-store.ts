import type { CodePushState, DownloadProgress } from '../../typings/react-native-code-push';
import { initialState, reduce, UpdateEvent } from './update-state';

// An external store, not React state, because the legacy non-React functions in CodePush.js also update it.
// getSnapshot(), getDownloadProgress() and subscribe() have the shape that React's useSyncExternalStore expects.
export interface UpdateStore {
  getSnapshot(): CodePushState;
  getDownloadProgress(): DownloadProgress | undefined;
  subscribe(listener: () => void): () => void;
  dispatch(event: UpdateEvent): void;
}

export function createUpdateStore(): UpdateStore {
  let state = initialState;
  const listeners = new Set<() => void>();

  // Closures, not methods: useSyncExternalStore calls them unbound.
  return {
    getSnapshot: () => state.snapshot,
    getDownloadProgress: () => state.downloadProgress,
    subscribe: (listener) => {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
    dispatch: (event) => {
      const previous = state;
      state = reduce(state, event);
      if (state.snapshot === previous.snapshot && state.downloadProgress === previous.downloadProgress) {
        return;
      }
      // Every listener hears every change. useSyncExternalStore re-renders a component only when the value it reads
      // changes, so a progress event does not re-render a component that only calls useCodePush().
      // A copy, so a listener that unsubscribes during the loop does not skip the next one.
      Array.from(listeners).forEach((listener) => listener());
    },
  };
}
