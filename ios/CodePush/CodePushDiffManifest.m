#import "CodePushDiffManifest.h"

#import <sys/stat.h>

static NSString *const CodePushDiffManifestErrorDomain = @"CodePushDiffManifestError";

static NSError *missingFieldError(NSString *fieldName, NSString *context)
{
    return [NSError errorWithDomain:CodePushDiffManifestErrorDomain
                                code:1
                            userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Diff manifest %@ is missing required field \"%@\"", context, fieldName] }];
}

static NSError *malformedManifestError(NSString *message)
{
    return [NSError errorWithDomain:CodePushDiffManifestErrorDomain
                                code:2
                            userInfo:@{ NSLocalizedDescriptionKey: message }];
}

// Resolves every symlink in `path`. Returns nil if `path` does not exist or
// cannot be read.
static NSString *canonicalPathOfExistingItem(NSString *path)
{
    char buffer[PATH_MAX];
    if (realpath(path.fileSystemRepresentation, buffer) == NULL) {
        return nil;
    }
    return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:buffer length:strlen(buffer)];
}

// realpath() needs the whole path to exist, but the files a patch writes do not
// exist yet. Canonicalize the deepest ancestor that does exist, then re-append
// the components below it. Returns nil if one of those components is a dangling
// symlink: it would survive canonicalization as its own path, and a write to it
// would still follow the link out of the folder.
static NSString *canonicalPathAllowingMissingComponents(NSString *path)
{
    NSMutableArray<NSString *> *missingComponents = [NSMutableArray array];
    NSString *existingAncestor = path;
    NSString *canonicalPath = nil;

    while ((canonicalPath = canonicalPathOfExistingItem(existingAncestor)) == nil) {
        NSString *parent = [existingAncestor stringByDeletingLastPathComponent];
        if (parent.length == 0 || [parent isEqualToString:existingAncestor]) {
            return nil;
        }
        [missingComponents insertObject:existingAncestor.lastPathComponent atIndex:0];
        existingAncestor = parent;
    }

    for (NSString *component in missingComponents) {
        canonicalPath = [canonicalPath stringByAppendingPathComponent:component];

        struct stat fileInfo;
        if (lstat(canonicalPath.fileSystemRepresentation, &fileInfo) == 0 && S_ISLNK(fileInfo.st_mode)) {
            return nil;
        }
    }
    return canonicalPath;
}

@implementation CodePushPatchedFileEntry

- (instancetype)initWithAlgo:(NSString *)algo
                    baseHash:(NSString *)baseHash
                  targetHash:(NSString *)targetHash
                       patch:(NSString *)patch
{
    self = [super init];
    if (self) {
        _algo = [algo copy];
        _baseHash = [baseHash copy];
        _targetHash = [targetHash copy];
        _patch = [patch copy];
    }
    return self;
}

@end

@implementation CodePushDiffManifest

- (instancetype)initWithVersion:(NSInteger)version
                    deletedFiles:(NSArray<NSString *> *)deletedFiles
                    patchedFiles:(NSDictionary<NSString *, CodePushPatchedFileEntry *> *)patchedFiles
{
    self = [super init];
    if (self) {
        _version = version;
        _deletedFiles = [deletedFiles copy];
        _patchedFiles = [patchedFiles copy];
    }
    return self;
}

+ (nullable instancetype)manifestFromJSON:(NSDictionary *)json error:(NSError **)error
{
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) *error = missingFieldError(@"version/deletedFiles/patchedFiles", @"root");
        return nil;
    }

    // A version we cannot read is a hard failure: silently treating it as 1
    // would skip every patch and install the old bytes under the new hash.
    id versionValue = json[@"version"];
    NSInteger version = 1;
    if (versionValue != nil && ![versionValue isKindOfClass:[NSNull class]]) {
        if (![versionValue isKindOfClass:[NSNumber class]]) {
            if (error) *error = malformedManifestError([NSString stringWithFormat:@"Diff manifest field \"version\" must be a number, but is \"%@\"", versionValue]);
            return nil;
        }
        version = [versionValue integerValue];
    }

    NSArray *deletedFilesJSON = json[@"deletedFiles"];
    NSMutableArray<NSString *> *deletedFiles = [NSMutableArray array];
    if ([deletedFilesJSON isKindOfClass:[NSArray class]]) {
        for (id deletedFileName in deletedFilesJSON) {
            if (![deletedFileName isKindOfClass:[NSString class]]) {
                if (error) *error = missingFieldError(@"deletedFiles", @"entry is not a string");
                return nil;
            }
            [deletedFiles addObject:deletedFileName];
        }
    }

    NSDictionary *patchedFilesJSON = json[@"patchedFiles"];
    NSMutableDictionary<NSString *, CodePushPatchedFileEntry *> *patchedFiles = [NSMutableDictionary dictionary];
    if ([patchedFilesJSON isKindOfClass:[NSDictionary class]]) {
        for (NSString *relativePath in patchedFilesJSON) {
            NSDictionary *entryJSON = patchedFilesJSON[relativePath];
            if (![entryJSON isKindOfClass:[NSDictionary class]]) {
                if (error) *error = missingFieldError(relativePath, @"patchedFiles entry");
                return nil;
            }

            NSString *algo = entryJSON[@"algo"];
            NSString *baseHash = entryJSON[@"baseHash"];
            NSString *targetHash = entryJSON[@"targetHash"];
            NSString *patch = entryJSON[@"patch"];
            if (![algo isKindOfClass:[NSString class]] || ![baseHash isKindOfClass:[NSString class]] ||
                ![targetHash isKindOfClass:[NSString class]] || ![patch isKindOfClass:[NSString class]]) {
                if (error) *error = missingFieldError(@"algo/baseHash/targetHash/patch", [NSString stringWithFormat:@"patchedFiles[\"%@\"]", relativePath]);
                return nil;
            }

            patchedFiles[relativePath] = [[CodePushPatchedFileEntry alloc] initWithAlgo:algo
                                                                                 baseHash:baseHash
                                                                               targetHash:targetHash
                                                                                    patch:patch];
        }
    }

    // Only version 2 and up carry patches. A version 1 manifest that lists them
    // is malformed, and applying none of them would leave the old bytes behind.
    if (version < 2 && patchedFiles.count > 0) {
        if (error) *error = malformedManifestError([NSString stringWithFormat:@"Diff manifest version %ld does not support binary diff patches, but the manifest lists %lu of them", (long)version, (unsigned long)patchedFiles.count]);
        return nil;
    }

    return [[CodePushDiffManifest alloc] initWithVersion:version
                                              deletedFiles:deletedFiles
                                              patchedFiles:patchedFiles];
}

+ (nullable NSString *)resolvePath:(NSString *)relativePath withinFolder:(NSString *)folder
{
    if (relativePath.length == 0 || relativePath.isAbsolutePath) {
        return nil;
    }
    for (NSString *component in relativePath.pathComponents) {
        if ([component isEqualToString:@".."]) {
            return nil;
        }
    }

    NSString *canonicalFolder = canonicalPathOfExistingItem(folder);
    if (canonicalFolder == nil) {
        return nil;
    }

    NSString *resolved = canonicalPathAllowingMissingComponents([canonicalFolder stringByAppendingPathComponent:relativePath]);
    if (resolved == nil) {
        return nil;
    }
    if (![resolved isEqualToString:canonicalFolder] &&
        ![resolved hasPrefix:[canonicalFolder stringByAppendingString:@"/"]]) {
        return nil;
    }
    return resolved;
}

@end
