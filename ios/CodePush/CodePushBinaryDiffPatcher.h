#import <Foundation/Foundation.h>
#import "CodePushDiffManifest.h"

NS_ASSUME_NONNULL_BEGIN

@interface CodePushBinaryDiffPatcher : NSObject

// Applies every entry in manifest.patchedFiles: verifies the pre-patch file
// against baseHash, applies the patch into newUpdateFolder, then verifies
// the result against targetHash.
//
// All three folder arguments must exist on disk. Files within them need not,
// the patch output and its parent directories are created as needed.
//
// Returns NO and sets *error on the first failure.
+ (BOOL)applyBinaryDiffPatchesFromManifest:(CodePushDiffManifest *)manifest
                      currentPackageFolder:(NSString *)currentPackageFolder
                            unzippedFolder:(NSString *)unzippedFolder
                            newUpdateFolder:(NSString *)newUpdateFolder
                                     error:(NSError **)error
    NS_SWIFT_NAME(applyBinaryDiffPatches(manifest:currentPackageFolder:unzippedFolder:newUpdateFolder:));

@end

NS_ASSUME_NONNULL_END
