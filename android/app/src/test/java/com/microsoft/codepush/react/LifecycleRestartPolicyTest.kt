package com.microsoft.codepush.react

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LifecycleRestartPolicyTest {

    private var nowMs = 0L
    private val policy = LifecycleRestartPolicy { nowMs }

    private val immediate = CodePushInstallMode.IMMEDIATE.value
    private val onNextRestart = CodePushInstallMode.ON_NEXT_RESTART.value
    private val onNextResume = CodePushInstallMode.ON_NEXT_RESUME.value
    private val onNextSuspend = CodePushInstallMode.ON_NEXT_SUSPEND.value

    private fun pauseFor(seconds: Long): Boolean {
        policy.onPause()
        nowMs += seconds * 1000
        return policy.onResume()
    }

    @Test
    fun onResume_withoutPause_neverRestarts() {
        // Given
        policy.onInstall(onNextResume, 0)

        // When / Then
        assertFalse(policy.onResume())
    }

    @Test
    fun onResume_onNextRestart_neverRestarts() {
        // Given
        policy.onInstall(onNextRestart, 0)

        // When / Then
        assertFalse(pauseFor(600))
    }

    @Test
    fun onResume_immediate_restartsAfterAnyBackground() {
        // Given
        policy.onInstall(immediate, 600)

        // When / Then
        assertTrue(pauseFor(1))
    }

    @Test
    fun onResume_onNextResume_restartsOnlyAfterTheMinimum() {
        // Given
        policy.onInstall(onNextResume, 10)

        // When / Then
        assertFalse(pauseFor(9))
        assertTrue(pauseFor(10))
    }

    @Test
    fun onResume_onNextResume_withZeroMinimum_restartsAtAnyResume() {
        // Given
        policy.onInstall(onNextResume, 0)

        // When / Then
        assertTrue(pauseFor(0))
    }

    @Test
    fun onResume_onNextSuspend_restartsWhenTheTimerDidNotFire() {
        // Given
        policy.onInstall(onNextSuspend, 10)

        // When / Then
        assertTrue(pauseFor(12))
    }

    @Test
    fun onResume_afterReset_neverRestarts() {
        // Given
        policy.onInstall(onNextResume, 0)
        policy.reset()

        // When / Then
        assertFalse(pauseFor(600))
    }

    @Test
    fun onResume_usesTheLatestInstall() {
        // Given
        policy.onInstall(onNextResume, 0)
        policy.onInstall(onNextRestart, 0)

        // When / Then
        assertFalse(pauseFor(600))
    }

    @Test
    fun onPause_returnsTheSuspendDelayOnlyForOnNextSuspend() {
        // Given
        policy.onInstall(onNextSuspend, 30)

        // When / Then
        assertEquals(30_000L, policy.onPause())
        policy.onInstall(onNextResume, 30)
        assertNull(policy.onPause())
    }

    @Test
    fun onInstall_onNextResume_appliesNowAfterALongEnoughBackground() {
        // Given
        pauseFor(12)

        // When / Then
        assertTrue(policy.onInstall(onNextResume, 10))
    }

    @Test
    fun onInstall_onNextResume_waitsAfterAShortBackground() {
        // Given
        pauseFor(3)

        // When / Then
        assertFalse(policy.onInstall(onNextResume, 10))
    }

    @Test
    fun onInstall_onNextResume_withZeroMinimum_waitsForTheNextResume() {
        // Given
        pauseFor(600)

        // When / Then
        assertFalse(policy.onInstall(onNextResume, 0))
    }

    @Test
    fun onInstall_otherModes_neverApplyNow() {
        // Given
        pauseFor(600)

        // When / Then
        assertFalse(policy.onInstall(onNextRestart, 10))
        assertFalse(policy.onInstall(onNextSuspend, 10))
        assertFalse(policy.onInstall(immediate, 10))
    }
}
