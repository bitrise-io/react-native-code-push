// Trimmed from https://github.com/microsoft/code-push/blob/master/src/script/types.ts (archived, MIT licensed)
// Upstream's types.ts also contains management/CLI-API types (Account, App, Deployment, ...)
// that are irrelevant to the on-device acquisition client

/*in*/
export interface DeploymentStatusReport {
    app_version: string;
    client_unique_id?: string;
    deployment_key: string;
    previous_deployment_key?: string;
    previous_label_or_app_version?: string;
    label?: string;
    status?: string;
}

export type DownloadStatusValue = "DownloadSucceeded" | "DownloadFailed";

/*in*/
export interface DownloadReport {
    client_unique_id: string;
    deployment_key: string;
    label: string;
    package_hash: string;
    package_size_bytes: number;
    download_duration_ms?: number;
    status: DownloadStatusValue;
}

/*out*/
export interface UpdateCheckResponse {
    download_url?: string;
    description?: string;
    is_available: boolean;
    is_disabled?: boolean;
    target_binary_range: string;
    /*generated*/ label?: string;
    /*generated*/ package_hash?: string;
    package_size?: number;
    should_run_binary_version?: boolean;
    update_app_version?: boolean;
    is_mandatory?: boolean;
}

/*in*/
export interface UpdateCheckRequest {
    app_version: string;
    client_unique_id?: string;
    deployment_key: string;
    is_companion?: boolean;
    label?: string;
    package_hash?: string;
}
