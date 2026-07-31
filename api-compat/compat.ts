/**
 * API compatibility test: q Therefore, we have this little helper which helps us catch API breakage.
 *
 * This code is not run, it only needs to compile. It exercises every
 * public export of typings/react-native-code-push.d.ts (every interface
 * field, every function overload, every enum member) so that `tsc` fails
 * if a future change narrows, renames, or removes any part of the public
 * API surface. Additions are fine; this file should never need edits for
 * a purely additive change to the .d.ts.
 *
 * Run with: npm run check:api-compat
 */

import CodePush, {
    CodePushOptions,
    DownloadProgress,
    DownloadProgressCallback,
    HandleBinaryVersionMismatchCallback,
    LocalPackage,
    Package,
    RemotePackage,
    RollbackRetryOptions,
    StatusReport,
    SyncOptions,
    SyncStatusChangedCallback,
    UpdateDialog,
} from "../typings/react-native-code-push";

// ---- Package / LocalPackage / RemotePackage --------------------------

declare let pkg: Package;
const _appVersion: string = pkg.appVersion;
const _deploymentKey: string = pkg.deploymentKey;
const _description: string = pkg.description;
const _failedInstall: boolean = pkg.failedInstall;
const _isFirstRun: boolean = pkg.isFirstRun;
const _isMandatory: boolean = pkg.isMandatory;
const _isPending: boolean = pkg.isPending;
const _label: string = pkg.label;
const _packageHash: string = pkg.packageHash;
const _packageSize: number = pkg.packageSize;

declare let localPackage: LocalPackage;
localPackage.install(CodePush.InstallMode.IMMEDIATE).then((): void => undefined);
localPackage.install(CodePush.InstallMode.IMMEDIATE, 5).then((): void => undefined);

declare let remotePackage: RemotePackage;
const _downloadUrl: string = remotePackage.downloadUrl;
remotePackage.download().then((lp: LocalPackage): void => undefined);
remotePackage
    .download((progress: DownloadProgress): void => undefined)
    .then((lp: LocalPackage): void => undefined);

// ---- DownloadProgress --------------------------------------------------

declare let downloadProgress: DownloadProgress;
const _totalBytes: number = downloadProgress.totalBytes;
const _receivedBytes: number = downloadProgress.receivedBytes;

const _downloadProgressCallback: DownloadProgressCallback = (progress: DownloadProgress): void => undefined;

// ---- SyncOptions / CodePushOptions -------------------------------------

// All fields on SyncOptions are optional; if any becomes required this
// assignment starts failing.
const _emptySyncOptions: SyncOptions = {};

declare let syncOptions: SyncOptions;
const _syncDeploymentKey: string | undefined = syncOptions.deploymentKey;
const _installMode: CodePush.InstallMode | undefined = syncOptions.installMode;
const _mandatoryInstallMode: CodePush.InstallMode | undefined = syncOptions.mandatoryInstallMode;
const _minimumBackgroundDuration: number | undefined = syncOptions.minimumBackgroundDuration;
const _updateDialog: UpdateDialog | true | undefined = syncOptions.updateDialog;
const _rollbackRetryOptions: RollbackRetryOptions | undefined = syncOptions.rollbackRetryOptions;

declare let codePushOptions: CodePushOptions;
const _checkFrequency: CodePush.CheckFrequency = codePushOptions.checkFrequency;

// ---- UpdateDialog / RollbackRetryOptions -------------------------------

// All fields optional on both — same "still optional" guard as above.
const _emptyUpdateDialog: UpdateDialog = {};
const _emptyRollbackRetryOptions: RollbackRetryOptions = {};

declare let updateDialog: UpdateDialog;
const _appendReleaseDescription: boolean | undefined = updateDialog.appendReleaseDescription;
const _descriptionPrefix: string | undefined = updateDialog.descriptionPrefix;
const _mandatoryContinueButtonLabel: string | undefined = updateDialog.mandatoryContinueButtonLabel;
const _mandatoryUpdateMessage: string | undefined = updateDialog.mandatoryUpdateMessage;
const _optionalIgnoreButtonLabel: string | undefined = updateDialog.optionalIgnoreButtonLabel;
const _optionalInstallButtonLabel: string | undefined = updateDialog.optionalInstallButtonLabel;
const _optionalUpdateMessage: string | undefined = updateDialog.optionalUpdateMessage;
const _title: string | undefined = updateDialog.title;

declare let rollbackRetryOptions: RollbackRetryOptions;
const _delayInHours: number | undefined = rollbackRetryOptions.delayInHours;
const _maxRetryAttempts: number | undefined = rollbackRetryOptions.maxRetryAttempts;

// ---- StatusReport -------------------------------------------------------

declare let statusReport: StatusReport;
const _status: CodePush.DeploymentStatus = statusReport.status;
const _statusAppVersion: string | undefined = statusReport.appVersion;
const _statusPackage: Package | undefined = statusReport.package;
const _previousDeploymentKey: string | undefined = statusReport.previousDeploymentKey;
const _previousLabelOrAppVersion: string | undefined = statusReport.previousLabelOrAppVersion;

// ---- Callback type aliases ----------------------------------------------

const _syncStatusChangedCallback: SyncStatusChangedCallback = (status: CodePush.SyncStatus): void => undefined;
const _handleBinaryVersionMismatchCallback: HandleBinaryVersionMismatchCallback = (
    update: RemotePackage
): void => undefined;

// ---- CodePush() HOC overloads --------------------------------------------

const _wrappedWithOptions = CodePush({ checkFrequency: CodePush.CheckFrequency.MANUAL })(class {});
const _wrappedComponent = CodePush(class {});

// ---- CodePush namespace members ------------------------------------------

const _defaultUpdateDialog: UpdateDialog = CodePush.DEFAULT_UPDATE_DIALOG;

CodePush.checkForUpdate().then((rp: RemotePackage | null): void => undefined);
CodePush.checkForUpdate("deploymentKey").then((rp: RemotePackage | null): void => undefined);
CodePush.checkForUpdate("deploymentKey", (update: RemotePackage): void => undefined).then(
    (rp: RemotePackage | null): void => undefined
);

CodePush.getUpdateMetadata().then((lp: LocalPackage | null): void => undefined);
CodePush.getUpdateMetadata(CodePush.UpdateState.RUNNING).then((lp: LocalPackage | null): void => undefined);

CodePush.notifyAppReady().then((sr: StatusReport | void): void => undefined);

CodePush.allowRestart();
CodePush.disallowRestart();
CodePush.clearUpdates();

CodePush.restartApp();
CodePush.restartApp(true);

CodePush.sync().then((s: CodePush.SyncStatus): void => undefined);
CodePush.sync(syncOptions).then((s: CodePush.SyncStatus): void => undefined);
CodePush.sync(syncOptions, (s: CodePush.SyncStatus): void => undefined).then(
    (s: CodePush.SyncStatus): void => undefined
);
CodePush.sync(
    syncOptions,
    (s: CodePush.SyncStatus): void => undefined,
    (progress: DownloadProgress): void => undefined
).then((s: CodePush.SyncStatus): void => undefined);
CodePush.sync(
    syncOptions,
    (s: CodePush.SyncStatus): void => undefined,
    (progress: DownloadProgress): void => undefined,
    (update: RemotePackage): void => undefined
).then((s: CodePush.SyncStatus): void => undefined);

// ---- Enums: reference every member by name -------------------------------

const _installModes: CodePush.InstallMode[] = [
    CodePush.InstallMode.IMMEDIATE,
    CodePush.InstallMode.ON_NEXT_RESTART,
    CodePush.InstallMode.ON_NEXT_RESUME,
    CodePush.InstallMode.ON_NEXT_SUSPEND,
];

const _syncStatuses: CodePush.SyncStatus[] = [
    CodePush.SyncStatus.UP_TO_DATE,
    CodePush.SyncStatus.UPDATE_INSTALLED,
    CodePush.SyncStatus.UPDATE_IGNORED,
    CodePush.SyncStatus.UNKNOWN_ERROR,
    CodePush.SyncStatus.SYNC_IN_PROGRESS,
    CodePush.SyncStatus.CHECKING_FOR_UPDATE,
    CodePush.SyncStatus.AWAITING_USER_ACTION,
    CodePush.SyncStatus.DOWNLOADING_PACKAGE,
    CodePush.SyncStatus.INSTALLING_UPDATE,
];

const _updateStates: CodePush.UpdateState[] = [
    CodePush.UpdateState.RUNNING,
    CodePush.UpdateState.PENDING,
    CodePush.UpdateState.LATEST,
];

const _deploymentStatuses: CodePush.DeploymentStatus[] = [
    CodePush.DeploymentStatus.FAILED,
    CodePush.DeploymentStatus.SUCCEEDED,
];

const _checkFrequencies: CodePush.CheckFrequency[] = [
    CodePush.CheckFrequency.ON_APP_START,
    CodePush.CheckFrequency.ON_APP_RESUME,
    CodePush.CheckFrequency.MANUAL,
];

export default undefined;
