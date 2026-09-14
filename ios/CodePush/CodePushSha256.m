#import "CodePushSha256.h"
#include <CommonCrypto/CommonDigest.h>

static NSString *const CodePushSha256ErrorDomain = @"CodePushSha256Error";

static NSString *hexStringForDigest(unsigned char digest[CC_SHA256_DIGEST_LENGTH])
{
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

NSString *CodePushSha256HexForData(NSData *data)
{
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    return hexStringForDigest(digest);
}

NSString *CodePushSha256HexForFile(NSString *filePath, NSError **error)
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (!fileHandle) {
        if (error) {
            *error = [NSError errorWithDomain:CodePushSha256ErrorDomain
                                          code:1
                                      userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not open file for reading: %@", filePath] }];
        }
        return nil;
    }

    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);

    static const NSUInteger kChunkSize = 1024 * 8;
    NSError *readError;
    while (YES) {
        NSData *chunk = [fileHandle readDataUpToLength:kChunkSize error:&readError];
        if (readError) {
            [fileHandle closeFile];
            if (error) {
                *error = [NSError errorWithDomain:CodePushSha256ErrorDomain
                                              code:2
                                          userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not read file: %@", filePath],
                                                      NSUnderlyingErrorKey: readError }];
            }
            return nil;
        }
        if (chunk.length == 0) {
            break;
        }
        CC_SHA256_Update(&context, chunk.bytes, (CC_LONG)chunk.length);
    }
    [fileHandle closeFile];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    return hexStringForDigest(digest);
}
