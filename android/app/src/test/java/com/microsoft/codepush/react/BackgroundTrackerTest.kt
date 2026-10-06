package com.microsoft.codepush.react

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BackgroundTrackerTest {

    private var nowMs = 0L
    private val tracker = BackgroundTracker { nowMs }

    private fun backgroundFor(seconds: Long) {
        tracker.onPause()
        nowMs += seconds * 1000
        tracker.onResume()
    }

    @Test
    fun onResume_withoutPause_returnsNull() {
        // When / Then
        assertNull(tracker.onResume())
    }

    @Test
    fun onResume_returnsWholeSecondsInBackground() {
        // Given
        tracker.onPause()
        nowMs += 12_900

        // When / Then
        assertEquals(12L, tracker.onResume())
    }

    @Test
    fun onResume_countsEachPauseOnce() {
        // Given
        backgroundFor(5)

        // When / Then
        assertNull(tracker.onResume())
    }

    @Test
    fun shouldApplyOnInstall_isFalseBeforeAnyBackground() {
        // When / Then
        assertFalse(tracker.shouldApplyOnInstall(5))
    }

    @Test
    fun shouldApplyOnInstall_isTrueWhenLastBackgroundReachedTheMinimum() {
        // Given
        backgroundFor(10)

        // When / Then
        assertTrue(tracker.shouldApplyOnInstall(10))
    }

    @Test
    fun shouldApplyOnInstall_isFalseWhenLastBackgroundWasShorter() {
        // Given
        backgroundFor(9)

        // When / Then
        assertFalse(tracker.shouldApplyOnInstall(10))
    }

    @Test
    fun shouldApplyOnInstall_isFalseForZeroMinimum() {
        // Given
        backgroundFor(600)

        // When / Then
        assertFalse(tracker.shouldApplyOnInstall(0))
    }

    @Test
    fun shouldApplyOnInstall_isFalseWhileTheAppIsInTheBackground() {
        // Given
        backgroundFor(600)
        tracker.onPause()

        // When / Then
        assertFalse(tracker.shouldApplyOnInstall(10))
    }

    @Test
    fun shouldApplyOnInstall_usesTheLatestCompletedBackground() {
        // Given
        backgroundFor(600)
        backgroundFor(2)

        // When / Then
        assertFalse(tracker.shouldApplyOnInstall(10))
    }
}
