#import <Foundation/Foundation.h>
#import "CodePushInstallMode.h"

// Holds no UIKit state, so the decisions are unit-testable. Synchronized because installs run
// on the module's method queue and lifecycle notifications arrive on the main thread.
@interface CodePushLifecycleRestartPolicy : NSObject

// The clock returns seconds from any fixed origin.
- (instancetype)initWithClock:(NSTimeInterval (^)(void))clock NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

// Returns YES when the app should restart right now.
- (BOOL)onInstallWithMode:(CodePushInstallMode)installMode
minimumBackgroundDuration:(int)minimumBackgroundDuration;

// Returns the seconds after which a pending update restarts the app, or nil for none.
- (NSNumber *)onResignActive;

- (void)onEnterBackground;

- (BOOL)onWillEnterForeground;

// YES when the app came back before the suspend timer was due.
- (BOOL)shouldCancelSuspendRestartOnBecomeActive;

@end
