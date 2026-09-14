package com.microsoft.codepush.react.diffpatch

import java.io.File

// Purposes of this interface:
// 1. Allows unit testing the business logic by substituting a fake PatchApplier.
// 2. Allows the SDK to support multiple patching algorithms in the future, if we ever need to.
interface PatchApplier {
    fun apply(oldFile: File, diffFile: File, newFile: File): DiffPatch.PatchResult
}

object NativeBsdiffPatchApplier : PatchApplier {
    override fun apply(oldFile: File, diffFile: File, newFile: File) =
        DiffPatch.applyPatch(oldFile.path, diffFile.path, newFile.path)
}

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
