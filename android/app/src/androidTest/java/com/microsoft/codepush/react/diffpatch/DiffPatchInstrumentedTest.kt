package com.microsoft.codepush.react.diffpatch

import android.content.res.AssetManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class DiffPatchInstrumentedTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var assets: AssetManager

    @Before
    fun setUp() {
        assets = InstrumentationRegistry.getInstrumentation().context.assets
    }

    // Assets are packed inside the APK, not addressable as filesystem paths, but
    // DiffPatch.applyPatch() takes real file paths. So each fixture has to be
    // copied out to a real file before it can be passed in.
    private fun copyAssetToFile(assetPath: String, destination: File) {
        assets.open(assetPath).use { input ->
            destination.outputStream().use { output -> input.copyTo(output) }
        }
    }

    private fun newFileFor(assetPath: String): File =
        File(tempFolder.newFolder(), File(assetPath).name)

    @Test
    fun applyPatch_basicDiff_succeedsAndMatchesExpectedOutput() {
        // An ordinary text-file diff, several inserted/changed/copied regions.
        val oldFile = newFileFor("basic/old.dat").also { copyAssetToFile("basic/old.dat", it) }
        val diffFile = newFileFor("basic/patch.bsdiff").also { copyAssetToFile("basic/patch.bsdiff", it) }
        val expectedNewFile = newFileFor("basic/new.dat").also { copyAssetToFile("basic/new.dat", it) }
        val outFile = File(tempFolder.root, "basic_out.dat")

        val result = DiffPatch.applyPatch(oldFile.absolutePath, diffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.OK, result)
        assertArrayEquals(expectedNewFile.readBytes(), outFile.readBytes())
    }

    @Test
    fun applyPatch_identicalOldAndNew_succeeds() {
        // Real BSDIFF40 patch whose only control entry is a single full-length copy from the old file.
        val oldFile = newFileFor("identical/old.dat").also { copyAssetToFile("identical/old.dat", it) }
        val diffFile = newFileFor("identical/patch.bsdiff").also { copyAssetToFile("identical/patch.bsdiff", it) }
        val expectedNewFile = newFileFor("identical/new.dat").also { copyAssetToFile("identical/new.dat", it) }
        val outFile = File(tempFolder.root, "identical_out.dat")

        val result = DiffPatch.applyPatch(oldFile.absolutePath, diffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.OK, result)
        assertArrayEquals(expectedNewFile.readBytes(), outFile.readBytes())
    }

    @Test
    fun applyPatch_emptyOldFile_succeeds() {
        val oldFile = newFileFor("empty_old/old.dat").also { copyAssetToFile("empty_old/old.dat", it) }
        val diffFile = newFileFor("empty_old/patch.bsdiff").also { copyAssetToFile("empty_old/patch.bsdiff", it) }
        val expectedNewFile = newFileFor("empty_old/new.dat").also { copyAssetToFile("empty_old/new.dat", it) }
        val outFile = File(tempFolder.root, "empty_old_out.dat")

        val result = DiffPatch.applyPatch(oldFile.absolutePath, diffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.OK, result)
        assertArrayEquals(expectedNewFile.readBytes(), outFile.readBytes())
    }

    @Test
    fun applyPatch_badDiffHeader_returnsBadDiffHeader() {
        // Well-formed length, wrong magic bytes (hand-written, not a real bsdiff output).
        val oldFile = newFileFor("bad_header/old.dat").also { copyAssetToFile("bad_header/old.dat", it) }
        val diffFile = newFileFor("bad_header/patch.bsdiff").also { copyAssetToFile("bad_header/patch.bsdiff", it) }
        val outFile = File(tempFolder.root, "bad_header_out.dat")

        val result = DiffPatch.applyPatch(oldFile.absolutePath, diffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.BAD_DIFF_HEADER, result)
        assertFalse("output file should not be left behind after a failed patch", outFile.exists())
    }

    @Test
    fun applyPatch_mismatchedOldFile_returnsPatchFailed() {
        // HDiffPatch's bounds checks must reject these inputs rather than reading out of range or
        // silently emitting corrupt output. wrong_old/old.dat is unrelated to (and shorter than)
        // basic/old.dat, so basic/patch.bsdiff's copy instructions reference offsets out of range for it.
        val oldFile = newFileFor("wrong_old/old.dat").also { copyAssetToFile("wrong_old/old.dat", it) }
        val diffFile = newFileFor("basic/patch.bsdiff").also { copyAssetToFile("basic/patch.bsdiff", it) }
        val outFile = File(tempFolder.root, "mismatched_old_out.dat")

        val result = DiffPatch.applyPatch(oldFile.absolutePath, diffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.PATCH_FAILED, result)
        assertFalse("output file should not be left behind after a failed patch", outFile.exists())
    }

    @Test
    fun applyPatch_missingOldFile_returnsOpenOldFailed() {
        val diffFile = newFileFor("basic/patch.bsdiff").also { copyAssetToFile("basic/patch.bsdiff", it) }
        val missingOldFile = File(tempFolder.root, "does_not_exist_old.dat")
        val outFile = File(tempFolder.root, "missing_old_out.dat")

        val result = DiffPatch.applyPatch(missingOldFile.absolutePath, diffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.OPEN_OLD_FAILED, result)
        assertFalse("output file should not be left behind after a failed patch", outFile.exists())
    }

    @Test
    fun applyPatch_missingDiffFile_returnsOpenDiffFailed() {
        val oldFile = newFileFor("basic/old.dat").also { copyAssetToFile("basic/old.dat", it) }
        val missingDiffFile = File(tempFolder.root, "does_not_exist.bsdiff")
        val outFile = File(tempFolder.root, "missing_diff_out.dat")

        val result = DiffPatch.applyPatch(oldFile.absolutePath, missingDiffFile.absolutePath, outFile.absolutePath)

        assertEquals(DiffPatch.PatchResult.OPEN_DIFF_FAILED, result)
        assertFalse("output file should not be left behind after a failed patch", outFile.exists())
    }
}
