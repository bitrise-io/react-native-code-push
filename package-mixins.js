import { NativeEventEmitter } from "react-native";
import log from "./logging";

// Reporting this event is important, but avoid blocking install()/restartApp() indefinitely
// on a stalled network request.
const REPORT_STATUS_DOWNLOAD_TIMEOUT_MS = 5000;

async function withTimeout(promise, timeoutMs) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`Timed out after ${timeoutMs}ms`)), timeoutMs);
  });

  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

// This function is used to augment remote and local
// package objects with additional functionality/properties
// beyond what is included in the metadata sent by the server.
module.exports = (NativeCodePush) => {
  const remote = (reportStatusDownload) => {
    return {
      async download(downloadProgressCallback) {
        if (!this.downloadUrl) {
          throw new Error("Cannot download an update without a download url");
        }

        let downloadProgressSubscription;
        if (downloadProgressCallback) {
          const codePushEventEmitter = new NativeEventEmitter(NativeCodePush);
          // Use event subscription to obtain download progress.
          downloadProgressSubscription = codePushEventEmitter.addListener(
            "CodePushDownloadProgress",
            downloadProgressCallback
          );
        }

        // Use the downloaded package info. Native code will save the package info
        // so that the client knows what the current package version is.
        try {
          const updatePackageCopy = Object.assign({}, this);
          Object.keys(updatePackageCopy).forEach((key) => (typeof updatePackageCopy[key] === 'function') && delete updatePackageCopy[key]);

          const downloadedPackage = await NativeCodePush.downloadUpdate(updatePackageCopy, !!downloadProgressCallback);

          if (reportStatusDownload) {
            try {
              await withTimeout(reportStatusDownload(this), REPORT_STATUS_DOWNLOAD_TIMEOUT_MS);
            } catch (err) {
              log(`Report download status failed: ${err}`);
            }
          }

          return { ...downloadedPackage, ...local };
        } finally {
          downloadProgressSubscription && downloadProgressSubscription.remove();
        }
      },

      isPending: false // A remote package could never be in a pending state
    };
  };

  const local = {
    async install(installMode = NativeCodePush.codePushInstallModeOnNextRestart, minimumBackgroundDuration = 0, updateInstalledCallback) {
      const localPackage = this;
      const localPackageCopy = Object.assign({}, localPackage); // In dev mode, React Native deep freezes any object queued over the bridge
      await NativeCodePush.installUpdate(localPackageCopy, installMode, minimumBackgroundDuration);
      updateInstalledCallback && updateInstalledCallback();
      if (installMode == NativeCodePush.codePushInstallModeImmediate) {
        NativeCodePush.restartApp(false);
      } else {
        NativeCodePush.clearPendingRestart();
        localPackage.isPending = true; // Mark the package as pending since it hasn't been applied yet
      }
    },

    isPending: false // A local package wouldn't be pending until it was installed
  };

  return { local, remote };
};
