export interface QueryPackage {
  appVersion?: string;
  packageHash?: string;
  [key: string]: unknown;
}

export function buildQueryPackage(
  localPackage: QueryPackage | null | undefined,
  config: { appVersion: string; packageHash?: string | null },
): QueryPackage {
  if (localPackage) {
    return localPackage;
  }
  const queryPackage: QueryPackage = { appVersion: config.appVersion };
  // Null in Android debug builds, which have no binary hash to report.
  if (config.packageHash) {
    queryPackage.packageHash = config.packageHash;
  }
  return queryPackage;
}
