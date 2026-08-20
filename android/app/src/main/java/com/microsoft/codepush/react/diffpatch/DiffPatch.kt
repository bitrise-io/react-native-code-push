package com.microsoft.codepush.react.diffpatch

object DiffPatch {

    /**
     * Applies the BSDIFF40 patch at diffFilePath to oldFilePath, writing the
     * patched result to newFilePath. newFilePath is created/overwritten, and
     * removed again if patching fails partway through.
     */
    fun applyPatch(oldFilePath: String, diffFilePath: String, newFilePath: String): PatchResult {
        ensureLibraryLoaded()
        return PatchResult.fromNativeCode(nativeBSPatchApply(oldFilePath, diffFilePath, newFilePath))
    }

    enum class PatchResult {
        OK,
        BAD_DIFF_HEADER,
        OPEN_OLD_FAILED,
        OPEN_DIFF_FAILED,
        OPEN_OUT_FAILED,
        OUT_OF_MEMORY,
        PATCH_FAILED,
        UNKNOWN;

        companion object {
            // Keep in sync with cpp/bspatch_bridge.h
            fun fromNativeCode(code: Int): PatchResult = when (code) {
                0 -> OK
                1 -> BAD_DIFF_HEADER
                2 -> OPEN_OLD_FAILED
                3 -> OPEN_DIFF_FAILED
                4 -> OPEN_OUT_FAILED
                5 -> OUT_OF_MEMORY
                6 -> PATCH_FAILED
                else -> UNKNOWN
            }
        }
    }

    @Volatile
    private var isLibraryLoaded = false

    @Synchronized
    private fun ensureLibraryLoaded() {
        if (!isLibraryLoaded) {
            System.loadLibrary("codepush_diffpatch")
            isLibraryLoaded = true
        }
    }


    @JvmStatic
    private external fun nativeBSPatchApply(oldFilePath: String, diffFilePath: String, newFilePath: String): Int
}
