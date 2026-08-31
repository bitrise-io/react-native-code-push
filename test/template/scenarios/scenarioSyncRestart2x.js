var CodePushWrapper = require("../codePushWrapper.js");
import CodePush from "@bitrise/code-push-sdk";

module.exports = {
    startTest: function (testApp) {
        testApp.sendCurrentAndPendingPackage()
            .then(() => {
                CodePushWrapper.sync(testApp, (status) => {
                    if (status === CodePush.SyncStatus.UPDATE_INSTALLED) {
                        testApp.sendCurrentAndPendingPackage().then(() => {
                            // Call sync() again without restarting: the update from the first call is still pending.
                            CodePushWrapper.sync(testApp, () => {}, undefined, { installMode: CodePush.InstallMode.ON_NEXT_RESTART });
                        });
                    }
                }, undefined, { installMode: CodePush.InstallMode.ON_NEXT_RESTART });
            });
    },

    getScenarioName: function () {
        return "Sync Restart 2x (no restart in between)";
    }
};
