package com.microsoft.codepush.react

import android.util.Log
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.MockedStatic
import org.mockito.Mockito
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class CodePushUpdateManagerTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var logMock: MockedStatic<Log>

    @Before
    fun mockAndroidLog() {
        // CodePushUtils.log() is used deep inside the SDK classes, which isn't stubbed for plain JVM unit tests.
        // We'd rather hack around this single instance (as long as this is the only one) than moving these tests to instrumented Android tests.
        logMock = Mockito.mockStatic(Log::class.java)
    }

    @After
    fun unmockAndroidLog() {
        logMock.close()
    }

    private fun manager() = CodePushUpdateManager(tempFolder.newFolder("documents").absolutePath)

    private fun updatePackage(hash: String) = JSONObject().apply {
        put(CodePushConstants.PACKAGE_HASH_KEY, hash)
    }

    private fun zipOf(vararg entries: Pair<String, String>): File {
        val zipFile = tempFolder.newFile("download.zip")
        ZipOutputStream(zipFile.outputStream()).use { zip ->
            for ((path, content) in entries) {
                zip.putNextEntry(ZipEntry(path))
                zip.write(content.toByteArray())
                zip.closeEntry()
            }
        }
        return zipFile
    }

    private fun rawBundleFile(content: String): File {
        val file = tempFolder.newFile("download.bundle")
        file.writeText(content)
        return file
    }

    // Registers `hash` as the currently installed package, with the given file contents, so that
    // getCurrentPackageFolderPath() resolves to it. Needed to set up diff-update scenarios.
    private fun installCurrentPackage(update: CodePushUpdateManager, hash: String, files: Map<String, String>): String {
        val folderPath = update.getPackageFolderPath(hash)
        File(folderPath).mkdirs()
        for ((relativePath, content) in files) {
            val file = File(folderPath, relativePath)
            file.parentFile?.mkdirs()
            file.writeText(content)
        }
        update.updateCurrentPackageInfo(JSONObject().apply { put(CodePushConstants.CURRENT_PACKAGE_KEY, hash) })
        return folderPath
    }

    @Test
    fun installDownloadedUpdate_rawBundle_movesFileIntoPlaceAndWritesMetadataWithoutBundlePath() {
        // Given
        val update = manager()
        val pkg = updatePackage("hash1")
        val downloadFile = rawBundleFile("raw jsbundle contents")
        val newUpdateFolderPath = update.getPackageFolderPath("hash1")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When
        update.installDownloadedUpdate(pkg, "index.android.bundle", null, downloadFile, false, newUpdateFolderPath, newUpdateMetadataPath)

        // Then
        val installedBundle = File(newUpdateFolderPath, "index.android.bundle")
        assertTrue(installedBundle.exists())
        assertEquals("raw jsbundle contents", installedBundle.readText())
        val metadata = JSONObject(File(newUpdateMetadataPath).readText())
        assertEquals("hash1", metadata.getString(CodePushConstants.PACKAGE_HASH_KEY))
        assertFalse("raw bundle updates never set a bundlePath", metadata.has(CodePushConstants.RELATIVE_BUNDLE_PATH_KEY))
    }

    @Test
    fun installDownloadedUpdate_zipFullUpdate_findsBundleInNestedFolderAndRecordsItsRelativePath() {
        // Given
        val update = manager()
        val entries = arrayOf(
            "sub/index.android.bundle" to "new bundle contents",
            "sub/asset.png" to "fake asset bytes",
        )
        val downloadFile = zipOf(*entries)
        val pkg = updatePackage("ff53f424bd583841638ff4e65f32dd71944ba72022d27ad6b8d8db8401b5bbf2")
        val newUpdateFolderPath = update.getPackageFolderPath("hash2")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When
        update.installDownloadedUpdate(pkg, "index.android.bundle", null, downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)

        // Then
        assertEquals("new bundle contents", File(newUpdateFolderPath, "sub/index.android.bundle").readText())
        val metadata = JSONObject(File(newUpdateMetadataPath).readText())
        assertEquals(
            CodePushUtils.appendPathComponent("sub", "index.android.bundle"),
            metadata.getString(CodePushConstants.RELATIVE_BUNDLE_PATH_KEY),
        )
    }

    @Test
    fun installDownloadedUpdate_zipMissingExpectedBundle_throwsInvalidUpdateException() {
        // Given
        val update = manager()
        val downloadFile = zipOf("other.txt" to "not a bundle")
        val pkg = updatePackage("hash3")
        val newUpdateFolderPath = update.getPackageFolderPath("hash3")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When / Then
        try {
            update.installDownloadedUpdate(pkg, "index.android.bundle", null, downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)
            fail("expected CodePushInvalidUpdateException")
        } catch (e: CodePushInvalidUpdateException) {
            assertTrue(e.message!!.contains("A JS bundle file named \"index.android.bundle\" could not be found"))
        }
    }

    @Test
    fun installDownloadedUpdate_zipFullUpdateWithNoPublicKeyAndNoSignatureAndWrongHash_throwsInvalidUpdateException() {
        // Given
        val update = manager()
        val downloadFile = zipOf("index.android.bundle" to "new bundle contents")
        val pkg = updatePackage("this-hash-does-not-match-the-real-contents")
        val newUpdateFolderPath = update.getPackageFolderPath("hash4")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When / Then
        try {
            update.installDownloadedUpdate(pkg, "index.android.bundle", null, downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)
            fail("expected CodePushInvalidUpdateException")
        } catch (e: CodePushInvalidUpdateException) {
            assertTrue(e.message!!.contains("The update contents failed the data integrity check."))
        }
    }

    @Test
    fun installDownloadedUpdate_publicKeyConfiguredButNoSignatureInBundle_throwsInvalidUpdateException() {
        // Given
        val update = manager()
        val downloadFile = zipOf("index.android.bundle" to "new bundle contents")
        val pkg = updatePackage("hash5")
        val newUpdateFolderPath = update.getPackageFolderPath("hash5")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When / Then
        try {
            update.installDownloadedUpdate(pkg, "index.android.bundle", "dummy-public-key", downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)
            fail("expected CodePushInvalidUpdateException")
        } catch (e: CodePushInvalidUpdateException) {
            assertTrue(e.message!!.contains("Error! Public key was provided but there is no JWT signature within app bundle to verify."))
        }
    }

    @Test
    fun installDownloadedUpdate_publicKeyConfiguredAndSignaturePresentButHashMismatch_throwsBeforeSignatureCheck() {
        // Given
        val update = manager()
        val downloadFile = zipOf(
            "index.android.bundle" to "new bundle contents",
            "CodePush/.codepushrelease" to "not-a-real-jwt",
        )
        val pkg = updatePackage("this-hash-does-not-match-the-real-contents")
        val newUpdateFolderPath = update.getPackageFolderPath("hash6")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When / Then
        try {
            update.installDownloadedUpdate(pkg, "index.android.bundle", "dummy-public-key", downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)
            fail("expected CodePushInvalidUpdateException")
        } catch (e: CodePushInvalidUpdateException) {
            assertTrue(e.message!!.contains("The update contents failed the data integrity check."))
        }
    }

    @Test
    fun installDownloadedUpdate_noPublicKeyButSignaturePresentInBundle_stillVerifiesFolderHash() {
        // Given
        val update = manager()
        val downloadFile = zipOf(
            "index.android.bundle" to "new bundle contents",
            "CodePush/.codepushrelease" to "not-a-real-jwt",
        )
        val pkg = updatePackage("this-hash-does-not-match-the-real-contents")
        val newUpdateFolderPath = update.getPackageFolderPath("hash7")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When / Then
        try {
            update.installDownloadedUpdate(pkg, "index.android.bundle", null, downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)
            fail("expected CodePushInvalidUpdateException")
        } catch (e: CodePushInvalidUpdateException) {
            assertTrue(e.message!!.contains("The update contents failed the data integrity check."))
        }
    }

    @Test
    fun installDownloadedUpdate_versionOneDiffUpdate_carriesOverKeptFilesDeletesRemovedOnesAndAppliesNewOnes() {
        // Given
        val update = manager()
        installCurrentPackage(update, "current-hash", mapOf(
            "kept.txt" to "kept contents",
            "old_extra.txt" to "stale contents",
        ))
        val downloadFile = zipOf(
            CodePushConstants.DIFF_MANIFEST_FILE_NAME to """{"version":1,"deletedFiles":["old_extra.txt"],"patchedFiles":{}}""",
            "index.android.bundle" to "new bundle contents",
        )
        // Deliberately wrong, so the folder-hash check at the end of the diff-update path throws -
        // but only after the merge below has already run, so we can still assert on its result.
        val pkg = updatePackage("this-hash-does-not-match-the-real-contents")
        val newUpdateFolderPath = update.getPackageFolderPath("new-hash")
        val newUpdateMetadataPath = CodePushUtils.appendPathComponent(newUpdateFolderPath, CodePushConstants.PACKAGE_FILE_NAME)

        // When / Then
        try {
            update.installDownloadedUpdate(pkg, "index.android.bundle", null, downloadFile, true, newUpdateFolderPath, newUpdateMetadataPath)
            fail("expected CodePushInvalidUpdateException from the folder hash check")
        } catch (e: CodePushInvalidUpdateException) {
            assertTrue(e.message!!.contains("The update contents failed the data integrity check."))
        }

        // Then (the merge above already ran, so its filesystem side effects are still checkable)
        assertEquals("kept contents", File(newUpdateFolderPath, "kept.txt").readText())
        assertFalse("deletedFiles entry should have been removed", File(newUpdateFolderPath, "old_extra.txt").exists())
        assertEquals("new bundle contents", File(newUpdateFolderPath, "index.android.bundle").readText())
        assertFalse("the manifest itself should not be carried into the installed package", File(newUpdateFolderPath, CodePushConstants.DIFF_MANIFEST_FILE_NAME).exists())
    }
}
