import { createContext } from 'react';

import type { UseCodePushResult } from '../../typings/react-native-code-push';
import { UpdateStore } from '../update-state/update-store';

export type UpdateActions = Pick<UseCodePushResult, 'checkForUpdate' | 'sync' | 'restartApp'>;

// The actions travel through the context, not an import, because they are implemented in the root CodePush.js, which
// src/ cannot import.
export interface CodePushContextValue {
  store: Pick<UpdateStore, 'getSnapshot' | 'getDownloadProgress' | 'subscribe'>;
  actions: UpdateActions;
}

export const StoreContext = createContext<CodePushContextValue | null>(null);
StoreContext.displayName = 'CodePushContext';
