#import "CodePushDiffManifest.h"

#import "CodePushErrorUtils.h"

#import <sys/stat.h>

static NSError *missingFieldError(NSString *fieldName, NSString *context)
{
    return [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest %@ is missing required field \"%@\"", context, fieldName]];
}

static NSError *wrongTypedFieldError(NSString *fieldName, NSString *context, id value)
{
    return [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest %@ field \"%@\" must be a string, but is %@", context, fieldName, NSStringFromClass([value class])]];
}

NSString *const CodePushDiffPatchesFolderName = @"__hcp_patches";

// The top-level entry that `relativePath` names under a base folder. Empty and
// "." components are skipped. The caller rejects ".." components first, so
// they need no handling here.
static NSString *topLevelComponentOf(NSString *relativePath)
{
    for (NSString *component in [relativePath componentsSeparatedByString:@"/"]) {
        if (component.length > 0 && ![component isEqualToString:@"."]) {
            return component;
        }
    }
    return nil;
}

static BOOL isAbsent(id value)
{
    return value == nil || [value isKindOfClass:[NSNull class]];
}

// Resolves every symlink in `path`. Returns nil if `path` does not exist or
// cannot be read.
static NSString *canonicalPathOfExistingItem(NSString *path)
{
    char pathBuffer[PATH_MAX];
    if (![path getFileSystemRepresentation:pathBuffer maxLength:sizeof(pathBuffer)]) {
        return nil;
    }

    char resolvedBuffer[PATH_MAX];
    if (realpath(pathBuffer, resolvedBuffer) == NULL) {
        return nil;
    }
    return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:resolvedBuffer length:strlen(resolvedBuffer)];
}

// Canonicalize the deepest path component that does exist, then re-append
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
        // "." refers to the same directory, so appending it verbatim would
        // leave the result unnormalized without changing what it points to.
        if ([component isEqualToString:@"."]) {
            continue;
        }
        canonicalPath = [canonicalPath stringByAppendingPathComponent:component];

        char componentBuffer[PATH_MAX];
        if (![canonicalPath getFileSystemRepresentation:componentBuffer maxLength:sizeof(componentBuffer)]) {
            return nil;
        }

        struct stat fileInfo;
        if (lstat(componentBuffer, &fileInfo) == 0 && S_ISLNK(fileInfo.st_mode)) {
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

- (BOOL)isBinaryDiff
{
    return self.version == 2;
}

+ (nullable instancetype)manifestFromJSON:(NSDictionary *)json error:(NSError **)error
{
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest must be a JSON object, but is %@", NSStringFromClass([json class])]];
        return nil;
    }

    // A version we cannot read is a hard failure: silently treating it as 1
    // would skip every patch and install the old bytes under the new hash.
    id versionValue = json[@"version"];
    NSInteger version = 1;
    if (!isAbsent(versionValue)) {
        BOOL isBoolean = versionValue == (id)kCFBooleanTrue || versionValue == (id)kCFBooleanFalse;
        double versionDouble = [versionValue isKindOfClass:[NSNumber class]] ? [versionValue doubleValue] : 0;
        if (![versionValue isKindOfClass:[NSNumber class]] || isBoolean || versionDouble != trunc(versionDouble)) {
            if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest field \"version\" must be an integer, but is \"%@\"", versionValue]];
            return nil;
        }
        version = [versionValue integerValue];
    }

    id deletedFilesJSON = json[@"deletedFiles"];
    NSMutableArray<NSString *> *deletedFiles = [NSMutableArray array];
    if (!isAbsent(deletedFilesJSON)) {
        if (![deletedFilesJSON isKindOfClass:[NSArray class]]) {
            if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest field \"deletedFiles\" must be an array, but is %@", NSStringFromClass([deletedFilesJSON class])]];
            return nil;
        }
        for (id deletedFileName in (NSArray *)deletedFilesJSON) {
            if (![deletedFileName isKindOfClass:[NSString class]]) {
                if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest field \"deletedFiles\" must hold strings, but holds \"%@\"", deletedFileName]];
                return nil;
            }
            [deletedFiles addObject:deletedFileName];
        }
    }

    id patchedFilesJSON = json[@"patchedFiles"];
    NSMutableDictionary<NSString *, CodePushPatchedFileEntry *> *patchedFiles = [NSMutableDictionary dictionary];
    if (!isAbsent(patchedFilesJSON)) {
        if (![patchedFilesJSON isKindOfClass:[NSDictionary class]]) {
            if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest field \"patchedFiles\" must be an object, but is %@", NSStringFromClass([patchedFilesJSON class])]];
            return nil;
        }
        for (NSString *relativePath in (NSDictionary *)patchedFilesJSON) {
            NSString *context = [NSString stringWithFormat:@"patchedFiles[\"%@\"]", relativePath];
            NSString *reservedPatchesFolderPrefix = [CodePushDiffPatchesFolderName stringByAppendingString:@"/"];

            if ([[relativePath componentsSeparatedByString:@"/"] containsObject:@".."]) {
                if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest %@ must not contain \"..\" components", context]];
                return nil;
            }

            if ([topLevelComponentOf(relativePath) isEqualToString:CodePushDiffPatchesFolderName]) {
                if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest %@ targets the reserved \"%@\" folder, which is not part of the installed package", context, reservedPatchesFolderPrefix]];
                return nil;
            }

            id entryJSON = patchedFilesJSON[relativePath];
            if (![entryJSON isKindOfClass:[NSDictionary class]]) {
                if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest %@ must be an object, but is %@", context, NSStringFromClass([entryJSON class])]];
                return nil;
            }

            for (NSString *fieldName in @[@"algo", @"baseHash", @"targetHash", @"patch"]) {
                id fieldValue = entryJSON[fieldName];
                if (![fieldValue isKindOfClass:[NSString class]]) {
                    if (error) *error = isAbsent(fieldValue) ? missingFieldError(fieldName, context) : wrongTypedFieldError(fieldName, context, fieldValue);
                    return nil;
                }
            }

            NSString *patch = entryJSON[@"patch"];
            if (![patch hasPrefix:reservedPatchesFolderPrefix]) {
                if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest %@ field \"patch\" must be under the reserved \"%@\" prefix, but is \"%@\"", context, reservedPatchesFolderPrefix, patch]];
                return nil;
            }

            patchedFiles[relativePath] = [[CodePushPatchedFileEntry alloc] initWithAlgo:entryJSON[@"algo"]
                                                                               baseHash:entryJSON[@"baseHash"]
                                                                             targetHash:entryJSON[@"targetHash"]
                                                                                  patch:patch];
        }
    }

    // Only version 2 defines file patching.
    // A manifest of any other version that lists patched files is malformed,
    // and applying none of them would leave the old bytes behind.
    CodePushDiffManifest *manifest = [[CodePushDiffManifest alloc] initWithVersion:version
                                                                      deletedFiles:deletedFiles
                                                                      patchedFiles:patchedFiles];
    if (!manifest.isBinaryDiff && patchedFiles.count > 0) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:[NSString stringWithFormat:@"Diff manifest declares version %ld but lists %lu patchedFiles, which require version 2", (long)version, (unsigned long)patchedFiles.count]];
        return nil;
    }

    return manifest;
}

+ (nullable NSString *)resolvePath:(NSString *)relativePath
                      withinFolder:(NSString *)folder
                             error:(NSError **)error
{
    if (relativePath.length == 0) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:@"path is empty"];
        return nil;
    }
    if (relativePath.isAbsolutePath) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:@"path escapes expected directory"];
        return nil;
    }
    // A path the file system cannot represent - an embedded NUL, or one longer
    // than PATH_MAX - never reaches a syscall from here.
    char pathBuffer[PATH_MAX];
    if (![relativePath getFileSystemRepresentation:pathBuffer maxLength:sizeof(pathBuffer)]) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:@"path cannot be represented in the file system"];
        return nil;
    }
    for (NSString *component in relativePath.pathComponents) {
        if ([component isEqualToString:@".."]) {
            if (error) *error = [CodePushErrorUtils errorWithMessage:@"path escapes expected directory"];
            return nil;
        }
    }

    NSString *canonicalFolder = canonicalPathOfExistingItem(folder);
    if (canonicalFolder == nil) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:@"base folder does not exist or is not accessible"];
        return nil;
    }

    NSString *resolved = canonicalPathAllowingMissingComponents([canonicalFolder stringByAppendingPathComponent:relativePath]);
    if (resolved == nil) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:@"path escapes expected directory"];
        return nil;
    }
    // Callers treat the result as a file inside the folder, so the folder
    // itself (e.g. from "." or a symlink resolving back to it) must not pass.
    if (![resolved hasPrefix:[canonicalFolder stringByAppendingString:@"/"]]) {
        if (error) *error = [CodePushErrorUtils errorWithMessage:@"path escapes expected directory"];
        return nil;
    }
    return resolved;
}

@end
