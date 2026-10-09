// Trimmed from https://github.com/microsoft/code-push/blob/master/src/script/types.ts (archived, MIT licensed)
// Upstream's types.ts also contains management/CLI-API types (Account, App, Deployment, ...)
// that are irrelevant to the on-device acquisition client

/*in*/
export interface DeploymentStatusReport {
    app_version: string;
    capabilities?: string[];
    client_unique_id?: string;
    deployment_key: string;
    previous_deployment_key?: string;
    previous_label_or_app_version?: string;
    label?: string;
    status?: string;
    // Set only together with a deployed package. Absent for packages persisted by an older SDK.
    update_type?: UpdateTypeValue;
}

export type DownloadStatusValue = "DownloadSucceeded" | "DownloadFailed";

export type UpdateTypeValue = "full" | "file_level_diff" | "binary_diff";

/*in*/
export interface DownloadReport {
    client_unique_id: string;
    deployment_key: string;
    label: string;
    package_hash: string;
    package_size_bytes: number;
    download_duration_ms?: number;
    status: DownloadStatusValue;
    // Absent when the native side did not determine it, e.g. a download that failed before the package contents were read.
    update_type?: UpdateTypeValue;
}

/*out*/
export interface UpdateCheckResponse {
    download_url?: string;
    description?: string;
    is_available: boolean;
    is_disabled?: boolean;
    target_binary_range: string;
    /*generated*/ label?: string;
    /*generated*/ version_label?: string;
    /*generated*/ package_hash?: string;
    package_size?: number;
    should_run_binary_version?: boolean;
    update_app_version?: boolean;
    is_mandatory?: boolean;
}

/*in*/
export interface UpdateCheckRequest {
    app_version: string;
    capabilities?: string[];
    client_unique_id?: string;
    deployment_key: string;
    is_companion?: boolean;
    label?: string;
    package_hash?: string;
}
