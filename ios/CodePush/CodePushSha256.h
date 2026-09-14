#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// SHA-256 hex digest of a file's contents.
// Returns nil and sets *error if the file can't be opened/read.
NSString * _Nullable CodePushSha256HexForFile(NSString *filePath, NSError **error);

// SHA-256 hex digest of an in-memory buffer.
NSString *CodePushSha256HexForData(NSData *data);

NS_ASSUME_NONNULL_END
