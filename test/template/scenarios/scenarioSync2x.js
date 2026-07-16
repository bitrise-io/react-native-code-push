var CodePushWrapper = require("../codePushWrapper.js");
import CodePush from "@bitrise/code-push-sdk";

module.exports = {
    startTest: function (testApp) {
        CodePushWrapper.sync(testApp, undefined, undefined, { installMode: CodePush.InstallMode.IMMEDIATE });
        CodePushWrapper.sync(testApp, undefined, undefined, { installMode: CodePush.InstallMode.IMMEDIATE });
    },

    getScenarioName: function () {
        return "Sync 2x";
    }
};
