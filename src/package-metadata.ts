type PackageMetadata<T> = Omit<T, 'download' | 'install'>;

/** A copy of a package without its bound methods, `download()` and `install()`. */
export function packageMetadata<T extends object>(pkg: T): PackageMetadata<T> {
  return Object.fromEntries(
    Object.entries(pkg).filter(([, value]) => typeof value !== 'function'),
  ) as PackageMetadata<T>;
}
