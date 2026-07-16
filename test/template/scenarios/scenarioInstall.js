var CodePushWrapper = require("../codePushWrapper.js");
import CodePush from "@bitrise/code-push-sdk";

module.exports = {
    startTest: function (testApp) {
        CodePushWrapper.checkAndInstall(testApp, undefined, undefined, CodePush.InstallMode.IMMEDIATE);
    },

    getScenarioName: function () {
        return "Install";
    }
};
