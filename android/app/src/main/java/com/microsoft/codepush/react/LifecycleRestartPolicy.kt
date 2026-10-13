package com.microsoft.codepush.react

import android.os.SystemClock

// Holds no Android state besides the default clock, so the decisions are unit-testable.
// Synchronized because installs run on a background thread and lifecycle events on the UI thread.
internal class LifecycleRestartPolicy(clock: Clock) {
    // elapsedRealtime keeps counting in deep sleep and ignores wall clock changes.
    constructor() : this(Clock { SystemClock.elapsedRealtime() })

    private val tracker = BackgroundTracker(clock)
    private var installMode = CodePushInstallMode.ON_NEXT_RESTART.value
    private var minimumBackgroundDuration = 0

    /** Returns true when the app should restart right now. */
    @Synchronized
    fun onInstall(installMode: Int, minimumBackgroundDuration: Int): Boolean {
        this.installMode = installMode
        this.minimumBackgroundDuration = minimumBackgroundDuration
        return installMode == CodePushInstallMode.ON_NEXT_RESUME.value &&
            tracker.shouldApplyOnInstall(minimumBackgroundDuration)
    }

    @Synchronized
    fun onResume(): Boolean {
        val secondsInBackground = tracker.onResume() ?: return false
        return when (installMode) {
            // An immediate install cannot restart a backgrounded activity, so it restarts on return.
            CodePushInstallMode.IMMEDIATE.value -> true
            CodePushInstallMode.ON_NEXT_RESUME.value,
            CodePushInstallMode.ON_NEXT_SUSPEND.value -> secondsInBackground >= minimumBackgroundDuration
            else -> false
        }
    }

    /** Returns the delay in milliseconds after which a pending update restarts the app, or null for none. */
    @Synchronized
    fun onPause(): Long? {
        tracker.onPause()
        return if (installMode == CodePushInstallMode.ON_NEXT_SUSPEND.value) minimumBackgroundDuration * 1000L else null
    }

    // Without this, the restart that loads the bundle would trigger another restart on the next resume.
    @Synchronized
    fun reset() {
        installMode = CodePushInstallMode.ON_NEXT_RESTART.value
    }
}
