import { useContext, useSyncExternalStore } from 'react';

import type { DownloadProgress } from '../../typings/react-native-code-push';
import { StoreContext } from './store-context';

// Separate from useCodePush(), because progress changes up to once per frame during a download. Only the components
// that show it re-render that often.
export function useDownloadProgress(): DownloadProgress | undefined {
  const context = useContext(StoreContext);
  if (!context) {
    throw new Error('useDownloadProgress must be used inside <CodePushProvider>.');
  }
  return useSyncExternalStore(context.store.subscribe, context.store.getDownloadProgress);
}
