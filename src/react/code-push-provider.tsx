import { useEffect, useRef, useState } from 'react';

import type { CodePushProviderProps } from '../../typings/react-native-code-push';
import { AppLifecycleDeps, startAppLifecycle } from '../app-lifecycle/app-lifecycle';
import { CodePushContextValue, StoreContext } from './store-context';

export function createCodePushProvider(deps: AppLifecycleDeps, { store, actions }: CodePushContextValue) {
  function CodePushProvider({ children, checkFrequency, onError, ...syncOptions }: CodePushProviderProps) {
    const latest = useRef({ checkFrequency, onError, syncOptions });

    // Declared before the start effect, so it runs first. It runs after every render, so resume checks, onError and
    // the hook's actions read the latest props.
    useEffect(() => {
      latest.current = { checkFrequency, onError, syncOptions };
    });

    // Runs once per mount, after the whole tree commits, so a crash on the first render still rolls the update back.
    // Prop changes do not run the launch step again.
    useEffect(() => startAppLifecycle(deps, () => latest.current), []);

    // Created once, so state changes re-render only the components that call useCodePush(). The hook's calls default
    // to the Provider's props.
    const [contextValue] = useState<CodePushContextValue>(() => ({
      store,
      actions: {
        ...actions,
        sync: (options) => actions.sync({ ...latest.current.syncOptions, ...options }),
        checkForUpdate: (options) =>
          actions.checkForUpdate({ deploymentKey: latest.current.syncOptions.deploymentKey, ...options }),
      },
    }));

    return <StoreContext.Provider value={contextValue}>{children}</StoreContext.Provider>;
  }

  return CodePushProvider;
}
