import React from "react";
import CodePush, { CodePushProvider } from "@bitrise/code-push-sdk";

module.exports = {
    startTest: function (testApp) {
        testApp.readyAfterUpdate();
    },

    // The Provider's MANUAL launch step calls notifyAppReady(), so the update is kept. Without it, it rolls back.
    wrap: function (app) {
        return (
            <CodePushProvider checkFrequency={CodePush.CheckFrequency.MANUAL}>
                {app}
            </CodePushProvider>
        );
    },

    getScenarioName: function () {
        return "Good Update";
    }
};
