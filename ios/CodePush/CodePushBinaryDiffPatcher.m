#import "CodePushBinaryDiffPatcher.h"
#import "CodePushErrorUtils.h"
#import "CodePushSha256.h"
#import "bspatch_bridge.h"

static NSError *patchApplyError(NSString *relativePath, NSString *reason)
{
    return [CodePushErrorUtils errorWithMessage:
            [NSString stringWithFormat:@"Failed to apply binary diff patch for \"%@\": %@", relativePath, reason]];
}

// Keep in sync with shared/diffpatch/bspatch_bridge.h.
static NSString *describeBSPatchResult(CodePushBSPatchResult result)
{
    switch (result) {
        case CODEPUSH_BSPATCH_OK: return @"OK";
        case CODEPUSH_BSPATCH_ERR_BAD_DIFF_HEADER: return @"BAD_DIFF_HEADER";
        case CODEPUSH_BSPATCH_ERR_OPEN_OLD: return @"OPEN_OLD_FAILED";
        case CODEPUSH_BSPATCH_ERR_OPEN_DIFF: return @"OPEN_DIFF_FAILED";
        case CODEPUSH_BSPATCH_ERR_OPEN_OUT: return @"OPEN_OUT_FAILED";
        case CODEPUSH_BSPATCH_ERR_OOM: return @"OUT_OF_MEMORY";
        case CODEPUSH_BSPATCH_ERR_PATCH_FAILED: return @"PATCH_FAILED";
    }
    return [NSString stringWithFormat:@"UNKNOWN (%ld)", (long)result];
}

static NSString *resolveWithin(NSString *base, NSString *path, NSString *manifestEntry, NSError **error)
{
    NSError *resolveError = nil;
    NSString *resolved = [CodePushDiffManifest resolvePath:path withinFolder:base error:&resolveError];
    if (resolved == nil && error) {
        *error = patchApplyError(manifestEntry, resolveError.localizedDescription);
    }
    return resolved;
}

@implementation CodePushBinaryDiffPatcher

+ (BOOL)applyBinaryDiffPatchesFromManifest:(CodePushDiffManifest *)manifest
                      currentPackageFolder:(NSString *)currentPackageFolder
                            unzippedFolder:(NSString *)unzippedFolder
                            newUpdateFolder:(NSString *)newUpdateFolder
                                     error:(NSError **)error
{
    NSDictionary<NSString *, CodePushPatchedFileEntry *> *patchedFiles = manifest.patchedFiles;

    for (NSString *relativePath in patchedFiles) {
        CodePushPatchedFileEntry *entry = patchedFiles[relativePath];
        if (![entry.algo isEqualToString:@"bsdiff"]) {
            if (error) *error = patchApplyError(relativePath, [NSString stringWithFormat:@"unsupported patch algorithm: %@", entry.algo]);
            return NO;
        }
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *relativePath in patchedFiles) {
        CodePushPatchedFileEntry *entry = patchedFiles[relativePath];

        NSString *oldFile = resolveWithin(currentPackageFolder, relativePath, relativePath, error);
        if (!oldFile) return NO;

        NSError *oldFileHashError = nil;
        NSString *oldFileHash = CodePushSha256HexForFile(oldFile, &oldFileHashError);
        if (!oldFileHash) {
            if (error) *error = patchApplyError(relativePath, [NSString stringWithFormat:@"could not hash the file to patch: %@", oldFileHashError.localizedDescription]);
            return NO;
        }
        if (![oldFileHash isEqualToString:entry.baseHash]) {
            if (error) *error = patchApplyError(relativePath, [NSString stringWithFormat:@"baseHash mismatch: expected %@, got %@", entry.baseHash, oldFileHash]);
            return NO;
        }

        NSString *diffFile = resolveWithin(unzippedFolder, entry.patch, relativePath, error);
        if (!diffFile) return NO;

        NSString *newFile = resolveWithin(newUpdateFolder, relativePath, relativePath, error);
        if (!newFile) return NO;

        NSError *createDirError = nil;
        [fileManager createDirectoryAtPath:[newFile stringByDeletingLastPathComponent]
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&createDirError];
        if (createDirError) {
            if (error) *error = patchApplyError(relativePath, createDirError.localizedDescription);
            return NO;
        }

        CodePushBSPatchResult result = codepush_bspatch_apply(oldFile.fileSystemRepresentation,
                                                              diffFile.fileSystemRepresentation,
                                                              newFile.fileSystemRepresentation);
        if (result != CODEPUSH_BSPATCH_OK) {
            if (error) *error = patchApplyError(relativePath, [NSString stringWithFormat:@"patch failed: %@", describeBSPatchResult(result)]);
            return NO;
        }

        NSError *newFileHashError = nil;
        NSString *newFileHash = CodePushSha256HexForFile(newFile, &newFileHashError);
        if (!newFileHash) {
            if (error) *error = patchApplyError(relativePath, [NSString stringWithFormat:@"could not hash the patched file: %@", newFileHashError.localizedDescription]);
            return NO;
        }
        if (![newFileHash isEqualToString:entry.targetHash]) {
            if (error) *error = patchApplyError(relativePath, [NSString stringWithFormat:@"targetHash mismatch: expected %@, got %@", entry.targetHash, newFileHash]);
            return NO;
        }
    }

    return YES;
}

@end
