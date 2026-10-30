import { useContext, useMemo, useSyncExternalStore } from 'react';

import type { UseCodePushResult } from '../../typings/react-native-code-push';
import { StoreContext } from './store-context';

export function useCodePush(): UseCodePushResult {
  const context = useContext(StoreContext);
  // Without the Provider nothing calls notifyAppReady(), so every update would roll back.
  if (!context) {
    throw new Error('useCodePush must be used inside <CodePushProvider>.');
  }
  const { store, actions } = context;
  const state = useSyncExternalStore(store.subscribe, store.getSnapshot);
  // A new object only when the state changes, so it is safe in dependency arrays.
  return useMemo(() => ({ ...state, ...actions }), [state, actions]);
}
