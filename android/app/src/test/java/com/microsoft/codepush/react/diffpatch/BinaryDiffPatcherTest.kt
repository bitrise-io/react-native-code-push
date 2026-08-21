package com.microsoft.codepush.react.diffpatch

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

private class FakePatchApplier(private val apply: (File, File, File) -> DiffPatch.PatchResult) : PatchApplier {
    var invocationCount = 0
        private set

    override fun apply(oldFile: File, diffFile: File, newFile: File): DiffPatch.PatchResult {
        invocationCount++
        return apply.invoke(oldFile, diffFile, newFile)
    }
}

class BinaryDiffPatcherTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private fun manifestOf(patchedFiles: Map<String, PatchedFileEntry>) =
        DiffManifest(version = 2, deletedFiles = emptyList(), patchedFiles = patchedFiles)

    @Test
    fun applyBinaryDiffPatches_happyPath_writesPatchedFileAtRightPath() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val oldFile = File(currentPackageFolder, "index.android.bundle").apply {
            parentFile?.mkdirs()
            writeText("old hermes bytecode contents")
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val diffFile = File(unzippedFolder, "__hcp_patches/index.android.bundle").apply {
            parentFile?.mkdirs()
            writeText("fake diff bytes")
        }
        val newUpdateFolder = tempFolder.newFolder("newUpdate")
        val patchedBytes = "new hermes bytecode contents".toByteArray()

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(oldFile),
                    targetHash = sha256Hex(patchedBytes.inputStream()),
                    patch = "__hcp_patches/index.android.bundle",
                )
            )
        )
        val applier = FakePatchApplier { _, _, newFile -> newFile.writeBytes(patchedBytes); DiffPatch.PatchResult.OK }

        // When
        applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)

        // Then
        val newFile = File(newUpdateFolder, "index.android.bundle")
        assertTrue(newFile.exists())
        assertEquals("new hermes bytecode contents", newFile.readText())
        assertEquals(1, applier.invocationCount)
    }

    @Test
    fun applyBinaryDiffPatches_baseHashMismatch_throwsWithoutInvokingApplier() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        File(currentPackageFolder, "index.android.bundle").apply {
            parentFile?.mkdirs()
            writeText("old hermes bytecode contents")
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = "wrong-hash",
                    targetHash = "irrelevant",
                    patch = "__hcp_patches/index.android.bundle",
                )
            )
        )
        val applier = FakePatchApplier { _, _, _ -> DiffPatch.PatchResult.OK }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            assertEquals("index.android.bundle", e.relativePath)
        }
        assertEquals(0, applier.invocationCount)
    }

    @Test
    fun applyBinaryDiffPatches_applierReturnsNonOk_throws() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val oldFile = File(currentPackageFolder, "index.android.bundle").apply {
            parentFile?.mkdirs()
            writeText("old hermes bytecode contents")
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(oldFile),
                    targetHash = "irrelevant",
                    patch = "__hcp_patches/index.android.bundle",
                )
            )
        )
        val applier = FakePatchApplier { _, _, _ -> DiffPatch.PatchResult.PATCH_FAILED }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            assertEquals("index.android.bundle", e.relativePath)
        }
        assertEquals(1, applier.invocationCount)
    }

    @Test
    fun applyBinaryDiffPatches_targetHashMismatchAfterSuccessfulApply_throws() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val oldFile = File(currentPackageFolder, "index.android.bundle").apply {
            parentFile?.mkdirs()
            writeText("old hermes bytecode contents")
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(oldFile),
                    targetHash = "wrong-target-hash",
                    patch = "__hcp_patches/index.android.bundle",
                )
            )
        )
        val applier = FakePatchApplier { _, _, newFile -> newFile.writeText("actual output"); DiffPatch.PatchResult.OK }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            assertEquals("index.android.bundle", e.relativePath)
        }
    }

    @Test
    fun applyBinaryDiffPatches_unknownAlgo_throwsWithoutInvokingApplier() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "some-other-algo",
                    baseHash = "irrelevant",
                    targetHash = "irrelevant",
                    patch = "__hcp_patches/index.android.bundle",
                )
            )
        )
        val applier = FakePatchApplier { _, _, _ -> DiffPatch.PatchResult.OK }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            assertEquals("index.android.bundle", e.relativePath)
        }
        assertEquals(0, applier.invocationCount)
    }

    @Test
    fun applyBinaryDiffPatches_oneOfMultipleEntriesFails_wholeInstallAborts() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val goodOldFile = File(currentPackageFolder, "index.android.bundle").apply { writeText("good old hermes bytecode") }
        val badOldFile = File(currentPackageFolder, "assets/drawable-mdpi/ic_launcher.png").apply {
            parentFile?.mkdirs()
            writeText("bad old")
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(goodOldFile),
                    targetHash = sha256Hex("good new hermes bytecode".toByteArray().inputStream()),
                    patch = "__hcp_patches/index.android.bundle",
                ),
                "assets/drawable-mdpi/ic_launcher.png" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(badOldFile),
                    targetHash = "wrong-target-hash",
                    patch = "__hcp_patches/assets/drawable-mdpi/ic_launcher.png",
                ),
            )
        )
        val applier = FakePatchApplier { _, _, newFile -> newFile.writeText("good new hermes bytecode"); DiffPatch.PatchResult.OK }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            // one of the two entries is expected to fail; which one depends on map iteration order
            assertTrue(e.relativePath == "index.android.bundle" || e.relativePath == "assets/drawable-mdpi/ic_launcher.png")
        }
    }

    @Test
    fun applyBinaryDiffPatches_relativePathEscapesCurrentPackageFolder_throwsWithoutInvokingApplier() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")
        val secret = File(tempFolder.root, "secret.bundle").apply { writeText("outside the package folder") }

        val manifest = manifestOf(
            mapOf(
                "../secret.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(secret),
                    targetHash = "irrelevant",
                    patch = "__hcp_patches/secret.bundle",
                )
            )
        )
        val applier = FakePatchApplier { _, _, _ -> DiffPatch.PatchResult.OK }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            assertEquals("../secret.bundle", e.relativePath)
        }
        assertEquals(0, applier.invocationCount)
    }

    @Test
    fun applyBinaryDiffPatches_patchFieldEscapesUnzippedFolder_throwsWithoutInvokingApplier() {
        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val oldFile = File(currentPackageFolder, "index.android.bundle").apply {
            parentFile?.mkdirs()
            writeText("old hermes bytecode contents")
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        val newUpdateFolder = tempFolder.newFolder("newUpdate")
        File(tempFolder.root, "outside.bsdiff").writeText("fake diff bytes")

        val manifest = manifestOf(
            mapOf(
                "index.android.bundle" to PatchedFileEntry(
                    algo = "bsdiff",
                    baseHash = sha256Hex(oldFile),
                    targetHash = "irrelevant",
                    patch = "../outside.bsdiff",
                )
            )
        )
        val applier = FakePatchApplier { _, _, _ -> DiffPatch.PatchResult.OK }

        // When / Then
        try {
            applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)
            fail("expected BinaryDiffApplyException")
        } catch (e: BinaryDiffApplyException) {
            assertEquals("../outside.bsdiff", e.relativePath)
        }
        assertEquals(0, applier.invocationCount)
    }

    @Test
    fun applyBinaryDiffPatches_realBsdiffFixtureShape_appliesSuccessfully() {
        fun fixture(name: String) =
            checkNotNull(javaClass.getResourceAsStream("/binarydiff/basic/$name")) { "missing fixture $name" }

        // Given
        val currentPackageFolder = tempFolder.newFolder("current")
        val oldFile = File(currentPackageFolder, "index.android.bundle").apply {
            parentFile?.mkdirs()
            fixture("old.dat").use { input -> outputStream().use { input.copyTo(it) } }
        }
        val unzippedFolder = tempFolder.newFolder("unzipped")
        File(unzippedFolder, "__hcp_patches/index.android.bundle").apply {
            parentFile?.mkdirs()
            fixture("patch.bsdiff").use { input -> outputStream().use { input.copyTo(it) } }
        }
        val expectedNewBytes = fixture("new.dat").use { it.readBytes() }
        val newUpdateFolder = tempFolder.newFolder("newUpdate")

        val manifestJson = JSONObject(
            """
            {
              "version": 2,
              "deletedFiles": [],
              "patchedFiles": {
                "index.android.bundle": {
                  "algo": "bsdiff",
                  "baseHash": "${sha256Hex(oldFile)}",
                  "targetHash": "${sha256Hex(expectedNewBytes.inputStream())}",
                  "patch": "__hcp_patches/index.android.bundle"
                }
              }
            }
            """.trimIndent()
        )
        val manifest = parseDiffManifest(manifestJson)

        val applier = FakePatchApplier { _, diffFile, newFile ->
            assertTrue("diff file should exist at the manifest-resolved path", diffFile.exists())
            newFile.writeBytes(expectedNewBytes)
            DiffPatch.PatchResult.OK
        }

        // When
        applyBinaryDiffPatches(manifest, currentPackageFolder, unzippedFolder, newUpdateFolder, applier)

        // Then
        val newFile = File(newUpdateFolder, "index.android.bundle")
        assertTrue(newFile.exists())
        assertTrue(expectedNewBytes.contentEquals(newFile.readBytes()))
    }
}
