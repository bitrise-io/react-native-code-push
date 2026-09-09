#import <Foundation/Foundation.h>

@interface CodePushErrorUtils : NSObject

+ (NSError *)errorWithMessage:(NSString *)errorMessage;
+ (BOOL)isCodePushError:(NSError *)error;

@end
