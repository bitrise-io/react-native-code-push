import CodePush from "@bitrise/code-push-sdk";
import { AppState } from "react-native";

// Syncs on launch and on every resume, as many apps do. It does not report UPDATE_INSTALLED:
// the install restarts the app, so the report would race with the restart.
module.exports = {
    startTest: function (testApp) {
        const runSync = () => CodePush.sync({
            installMode: CodePush.InstallMode.ON_NEXT_RESTART,
            mandatoryInstallMode: CodePush.InstallMode.ON_NEXT_RESUME,
            minimumBackgroundDuration: 5
        }).then((status) => {
            if (status !== CodePush.SyncStatus.UPDATE_INSTALLED) {
                return testApp.onSyncStatus(status);
            }
        }, (error) => testApp.onSyncError(error));

        runSync();
        // iOS can deliver an "active" event shortly after launch, so only a "background" before it counts as a resume.
        let wasInBackground = false;
        AppState.addEventListener("change", (newState) => {
            if (newState === "background") {
                wasInBackground = true;
            } else if (newState === "active" && wasInBackground) {
                wasInBackground = false;
                runSync();
            }
        });
    },

    getScenarioName: function () {
        return "Sync Mandatory Resume Delay On Active Apply Now";
    }
};
