#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CodePushPatchedFileEntry : NSObject

// The only value this client understands at the moment is "bsdiff".
@property (nonatomic, readonly, copy) NSString *algo;
// SHA-256 hex of the file's content in the currently installed package. Checked before patching.
@property (nonatomic, readonly, copy) NSString *baseHash;
// SHA-256 hex the patched output must match. Checked after patching.
@property (nonatomic, readonly, copy) NSString *targetHash;
// Zip-relative path to the patch file, under the reserved patches folder prefix.
@property (nonatomic, readonly, copy) NSString *patch;

- (instancetype)initWithAlgo:(NSString *)algo
                    baseHash:(NSString *)baseHash
                  targetHash:(NSString *)targetHash
                       patch:(NSString *)patch;

@end

@interface CodePushDiffManifest : NSObject

// No version field, or version 1: original format, file-by-file patching only.
// Version 2: adds support for binary diff patching.
@property (nonatomic, readonly, assign) NSInteger version;
// Relative paths, from the old package, to delete rather than carry over into the new one.
@property (nonatomic, readonly, copy) NSArray<NSString *> *deletedFiles;
// Key: file's relative path in the package being installed.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, CodePushPatchedFileEntry *> *patchedFiles;

- (instancetype)initWithVersion:(NSInteger)version
                    deletedFiles:(NSArray<NSString *> *)deletedFiles
                    patchedFiles:(NSDictionary<NSString *, CodePushPatchedFileEntry *> *)patchedFiles;

// Parses a diff manifest from its already-deserialized JSON representation.
// Returns nil and sets *error if a required field is missing or malformed.
+ (nullable instancetype)manifestFromJSON:(NSDictionary *)json error:(NSError **)error NS_SWIFT_NAME(init(json:));

// Turns a relative path from a diff manifest into an absolute path under
// `folder`. Returns nil if the path can lead out of `folder`.
//
// Every path in a manifest is untrusted: the manifest and the files it refers
// to come from the downloaded update, which is unpacked before anything
// verifies it. `folder` is inside the app's own container, where the app
// sandbox does not apply - a relative path that climbs out of `folder`
// ("../../Library/Preferences/x"), or a symlink in `folder` pointing
// elsewhere in the container, can reach other app data such as the currently
// installed package. This method rejects those, and absolute paths too.
+ (nullable NSString *)resolvePath:(NSString *)relativePath
                      withinFolder:(NSString *)folder
    NS_SWIFT_NAME(resolvePath(_:withinFolder:));

@end

NS_ASSUME_NONNULL_END
