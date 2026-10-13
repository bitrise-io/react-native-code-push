package com.microsoft.codepush.react

internal fun interface Clock {
    fun nowMs(): Long
}

internal class BackgroundTracker(private val clock: Clock) {
    private var pausedAtMs: Long? = null
    private var lastCompletedSeconds: Long? = null

    @Synchronized
    fun onPause() {
        pausedAtMs = clock.nowMs()
    }

    // Null when no pause came first: React Native fires a resume right after a listener
    // is added to a foreground app, and that one must not count.
    @Synchronized
    fun onResume(): Long? {
        val pausedAt = pausedAtMs ?: return null
        pausedAtMs = null
        return ((clock.nowMs() - pausedAt) / 1000).also { lastCompletedSeconds = it }
    }

    // Zero never qualifies: it is the default, and must keep the update waiting for the next resume.
    @Synchronized
    fun shouldApplyOnInstall(minimumBackgroundDuration: Int): Boolean {
        val lastSeconds = lastCompletedSeconds ?: return false
        return minimumBackgroundDuration > 0 && pausedAtMs == null && lastSeconds >= minimumBackgroundDuration
    }
}
