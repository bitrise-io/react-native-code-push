import type { LocalPackage } from '../../typings/react-native-code-push';
import { packageMetadata } from '../package-metadata';
import type { UpdateStore } from './update-store';

type Dispatch = Pick<UpdateStore, 'dispatch'>;

export async function trackDownload<T>(store: Dispatch, download: () => Promise<T>): Promise<T> {
  store.dispatch({ type: 'downloadStarted' });
  try {
    const result = await download();
    store.dispatch({ type: 'downloadCompleted' });
    return result;
  } catch (error) {
    store.dispatch({ type: 'downloadFailed', error: error as Error });
    throw error;
  }
}

export async function trackInstall(store: Dispatch, localPackage: LocalPackage, install: () => Promise<void>) {
  try {
    await install();
  } catch (error) {
    store.dispatch({ type: 'installFailed', error: error as Error });
    throw error;
  }
  // A copy, because the caller changes the package after the install.
  store.dispatch({ type: 'updateInstalled', update: { ...packageMetadata(localPackage), isPending: true } });
}
