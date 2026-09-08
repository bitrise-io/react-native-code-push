#import <Foundation/Foundation.h>
#import "CodePushDiffManifest.h"

NS_ASSUME_NONNULL_BEGIN

@interface CodePushBinaryDiffPatcher : NSObject

// Applies every entry in manifest.patchedFiles: verifies the pre-patch file
// against baseHash, applies the patch into newUpdateFolder, then verifies
// the result against targetHash.
//
// Returns NO and sets *error on the first failure (unsupported algo, hash
// mismatch, or patch failure).
+ (BOOL)applyBinaryDiffPatchesFromManifest:(CodePushDiffManifest *)manifest
                      currentPackageFolder:(NSString *)currentPackageFolder
                            unzippedFolder:(NSString *)unzippedFolder
                            newUpdateFolder:(NSString *)newUpdateFolder
                                     error:(NSError **)error
    NS_SWIFT_NAME(applyBinaryDiffPatches(manifest:currentPackageFolder:unzippedFolder:newUpdateFolder:));

@end

NS_ASSUME_NONNULL_END
