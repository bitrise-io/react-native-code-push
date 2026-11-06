import { useEffect, useRef } from 'react';

import type { CodePushProviderProps } from '../../typings/react-native-code-push';
import { AppLifecycleDeps, startAppLifecycle } from '../app-lifecycle/app-lifecycle';
import { CodePushContextValue, StoreContext } from './store-context';

// The context value never changes, so state changes re-render only the components that call useCodePush().
export function createCodePushProvider(deps: AppLifecycleDeps, contextValue: CodePushContextValue) {
  function CodePushProvider({ children, checkFrequency, onError, ...syncOptions }: CodePushProviderProps) {
    const latest = useRef({ checkFrequency, onError, syncOptions });

    // Declared before the start effect, so it runs first. It runs after every render, so resume checks and onError
    // read the latest props.
    useEffect(() => {
      latest.current = { checkFrequency, onError, syncOptions };
    });

    // Runs once per mount, after the whole tree commits, so a crash on the first render still rolls the update back.
    // Prop changes do not run the launch step again.
    useEffect(() => startAppLifecycle(deps, () => latest.current), []);

    return <StoreContext.Provider value={contextValue}>{children}</StoreContext.Provider>;
  }

  return CodePushProvider;
}
