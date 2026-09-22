import * as assert from "assert";
import * as querystring from "querystring";

import * as acquisitionSdk from "../acquisition-sdk";
import * as mockApi from "./acquisition-rest-mock";

const configuration: acquisitionSdk.Configuration = {
    appVersion: "1.5.0",
    clientUniqueId: "My iPhone",
    deploymentKey: mockApi.validDeploymentKey,
    serverUrl: mockApi.serverUrl,
    enableDeltaUpdates: true
};

const deltaUpdatesDisabledConfiguration: acquisitionSdk.Configuration = { ...configuration, enableDeltaUpdates: undefined };

const currentPackage: acquisitionSdk.Package = {
    deploymentKey: mockApi.validDeploymentKey,
    description: "Standard description",
    label: "v1",
    appVersion: "1.5.0",
    packageHash: "hash001",
    isMandatory: false,
    packageSize: 100
};

const okResponse: acquisitionSdk.Http.Response = {
    statusCode: 200,
    body: JSON.stringify({ update_info: { is_available: false } })
};

// Captures the exact request the SDK sends, instead of simulating a server response - the
// point of these tests is what goes over the wire, not how the SDK reacts to a reply.
class CapturingRequester implements acquisitionSdk.Http.Requester {
    public lastUrl: string;
    public lastBody: string;

    public request(
        verb: acquisitionSdk.Http.Verb,
        url: string,
        requestBodyOrCallback: string | acquisitionSdk.Callback<acquisitionSdk.Http.Response>,
        callback?: acquisitionSdk.Callback<acquisitionSdk.Http.Response>
    ): void {
        this.lastUrl = url;

        if (typeof requestBodyOrCallback === "string") {
            this.lastBody = requestBodyOrCallback;
            callback(/*error*/ null, okResponse);
        } else {
            requestBodyOrCallback(/*error*/ null, okResponse);
        }
    }
}

describe("Capabilities advertisement", () => {
    it("update_check sends capabilities as a plain repeated query param, not bracketed", (done: Mocha.Done) => {
        var requester = new CapturingRequester();
        var acquisition = new acquisitionSdk.AcquisitionManager(requester, configuration);

        acquisition.queryUpdateWithCurrentPackage(currentPackage, () => {
            var query = requester.lastUrl.split("?")[1];
            var params = querystring.parse(query);

            assert.strictEqual(params.capabilities, "binary_diff:bsdiff");
            assert.strictEqual(query.includes("capabilities%5B%5D"), false, "must not use bracket notation");
            done();
        });
    });

    it("update_check omits undefined optional fields instead of the literal string \"undefined\"", (done: Mocha.Done) => {
        var requester = new CapturingRequester();
        var acquisition = new acquisitionSdk.AcquisitionManager(requester, configuration);
        var freshInstallPackage: acquisitionSdk.Package = { ...currentPackage, packageHash: undefined, label: undefined };

        acquisition.queryUpdateWithCurrentPackage(freshInstallPackage, () => {
            var query = requester.lastUrl.split("?")[1];
            var params = querystring.parse(query);

            assert.strictEqual(params.package_hash, undefined);
            assert.strictEqual(params.label, undefined);
            assert.strictEqual(query.includes("undefined"), false);
            done();
        });
    });

    it("report_status/deploy sends capabilities as a JSON array", (done: Mocha.Done) => {
        var requester = new CapturingRequester();
        var acquisition = new acquisitionSdk.AcquisitionManager(requester, configuration);

        acquisition.reportStatusDeploy(
            currentPackage,
            acquisitionSdk.AcquisitionStatus.DeploymentSucceeded,
            /*previousLabelOrAppVersion*/ undefined,
            /*previousDeploymentKey*/ undefined,
            () => {
                var body = JSON.parse(requester.lastBody);

                assert.deepStrictEqual(body.capabilities, ["binary_diff:bsdiff"]);
                done();
            }
        );
    });

    it("update_check sends no capabilities when delta updates are not enabled", (done: Mocha.Done) => {
        var requester = new CapturingRequester();
        var acquisition = new acquisitionSdk.AcquisitionManager(requester, deltaUpdatesDisabledConfiguration);

        acquisition.queryUpdateWithCurrentPackage(currentPackage, () => {
            var params = querystring.parse(requester.lastUrl.split("?")[1]);

            assert.strictEqual(params.capabilities, undefined);
            done();
        });
    });

    it("report_status/deploy sends an empty capabilities array when delta updates are not enabled", (done: Mocha.Done) => {
        var requester = new CapturingRequester();
        var acquisition = new acquisitionSdk.AcquisitionManager(requester, deltaUpdatesDisabledConfiguration);

        acquisition.reportStatusDeploy(
            currentPackage,
            acquisitionSdk.AcquisitionStatus.DeploymentSucceeded,
            /*previousLabelOrAppVersion*/ undefined,
            /*previousDeploymentKey*/ undefined,
            () => {
                var body = JSON.parse(requester.lastBody);

                assert.deepStrictEqual(body.capabilities, []);
                done();
            }
        );
    });
});
