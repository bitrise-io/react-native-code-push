var CodePushWrapper = require("../codePushWrapper.js");
import CodePush from "@bitrise/code-push-sdk";

module.exports = {
    startTest: function (testApp) {
        CodePushWrapper.sync(testApp, undefined, undefined,
            {
                installMode: CodePush.InstallMode.ON_NEXT_SUSPEND,
                minimumBackgroundDuration: 5
            });
    },

    getScenarioName: function () {
        return "Sync Suspend Delay";
    }
};
