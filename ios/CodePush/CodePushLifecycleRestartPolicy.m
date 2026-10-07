#import "CodePushLifecycleRestartPolicy.h"
#import <time.h>

@implementation CodePushLifecycleRestartPolicy {
    NSTimeInterval (^_clock)(void);
    CodePushInstallMode _installMode;
    int _minimumBackgroundDuration;
    BOOL _hasResigned;
    NSTimeInterval _lastResignedAt;
    // Seconds the app spent in its last completed background, or -1 before the first one.
    int _lastBackgroundDuration;
    BOOL _isInBackground;
}

- (instancetype)initWithClock:(NSTimeInterval (^)(void))clock
{
    self = [super init];
    if (self) {
        _clock = [clock copy];
        _installMode = CodePushInstallModeOnNextRestart;
        _lastBackgroundDuration = -1;
    }
    return self;
}

- (instancetype)init
{
    // CLOCK_MONOTONIC keeps counting while the device sleeps and ignores wall clock changes.
    // systemUptime and mach_absolute_time stop during sleep, so a night-long background would read as seconds.
    return [self initWithClock:^NSTimeInterval {
        return clock_gettime_nsec_np(CLOCK_MONOTONIC) / (NSTimeInterval)NSEC_PER_SEC;
    }];
}

- (int)durationInBackground
{
    if (!_hasResigned) {
        return 0;
    }
    return _clock() - _lastResignedAt;
}

- (BOOL)onInstallWithMode:(CodePushInstallMode)installMode
minimumBackgroundDuration:(int)minimumBackgroundDuration
{
    @synchronized (self) {
        _installMode = installMode;
        _minimumBackgroundDuration = minimumBackgroundDuration;

        // Zero is the default, and keeps the update waiting for the next resume.
        return installMode == CodePushInstallModeOnNextResume
            && minimumBackgroundDuration > 0
            && !_isInBackground
            && _lastBackgroundDuration >= minimumBackgroundDuration;
    }
}

- (NSNumber *)onResignActive
{
    @synchronized (self) {
        _hasResigned = YES;
        _lastResignedAt = _clock();
        return _installMode == CodePushInstallModeOnNextSuspend ? @(_minimumBackgroundDuration) : nil;
    }
}

- (void)onEnterBackground
{
    @synchronized (self) {
        _isInBackground = YES;
    }
}

- (BOOL)onWillEnterForeground
{
    @synchronized (self) {
        _isInBackground = NO;
        int durationInBackground = [self durationInBackground];
        _lastBackgroundDuration = durationInBackground;
        return _installMode == CodePushInstallModeOnNextResume
            && durationInBackground >= _minimumBackgroundDuration;
    }
}

- (BOOL)shouldCancelSuspendRestartOnBecomeActive
{
    @synchronized (self) {
        return _installMode == CodePushInstallModeOnNextSuspend
            && [self durationInBackground] < _minimumBackgroundDuration;
    }
}

@end
