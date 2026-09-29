#import "CodePush.h"

// TODO: NSLog has no log levels. When this code is rewritten in Swift, adopt os.Logger
// (https://developer.apple.com/documentation/os/logger) and add log severity levels.
void CPLog(NSString *formatString, ...) {
    va_list args;
    va_start(args, formatString);
    NSString *prependedFormatString = [NSString stringWithFormat:@"[CodePush] %@", formatString];
    NSLogv(prependedFormatString, args);
    va_end(args);
}