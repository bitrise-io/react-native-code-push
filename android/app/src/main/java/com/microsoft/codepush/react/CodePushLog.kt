package com.microsoft.codepush.react

import android.util.Log

// Uses the "ReactNative" logcat tag and the [CodePush] prefix, so that native lines show up next to
// React Native's own lines, and a single grep for "[CodePush]" finds both native and JS lines.
object CodePushLog {
    private const val PREFIX = "[CodePush] "

    @JvmStatic
    fun info(message: String) {
        Log.i(CodePushConstants.REACT_NATIVE_LOG_TAG, PREFIX + message)
    }

    @JvmStatic
    @JvmOverloads
    fun warn(message: String, tr: Throwable? = null) {
        Log.w(CodePushConstants.REACT_NATIVE_LOG_TAG, PREFIX + message, tr)
    }

    @JvmStatic
    @JvmOverloads
    fun error(message: String, tr: Throwable? = null) {
        Log.e(CodePushConstants.REACT_NATIVE_LOG_TAG, PREFIX + message, tr)
    }
}
