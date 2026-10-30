import type { CodePushState } from '../../typings/react-native-code-push';
import { initialState, reduce, UpdateEvent } from './update-state';

// An external store, not React state, because the legacy non-React functions in CodePush.js also update it.
// getSnapshot() and subscribe() have the shape that React's useSyncExternalStore expects.
export interface UpdateStore {
  getSnapshot(): CodePushState;
  subscribe(listener: () => void): () => void;
  dispatch(event: UpdateEvent): void;
}

export function createUpdateStore(): UpdateStore {
  let state = initialState;
  const listeners = new Set<() => void>();

  // Closures, not methods: useSyncExternalStore calls them unbound.
  return {
    getSnapshot: () => state.snapshot,
    subscribe: (listener) => {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
    dispatch: (event) => {
      const previous = state;
      state = reduce(state, event);
      if (state.snapshot === previous.snapshot) {
        return;
      }
      // A copy, so a listener that unsubscribes during the loop does not skip the next one.
      Array.from(listeners).forEach((listener) => listener());
    },
  };
}
