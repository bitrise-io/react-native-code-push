package com.microsoft.codepush.react.diffpatch

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DiffManifestTest {

    @Test
    fun parseDiffManifest_v1Shape_defaultsVersionToOneAndPatchedFilesToEmpty() {
        // Given
        val json = JSONObject().put("deletedFiles", org.json.JSONArray(listOf("stale.js", "old/asset.png")))

        // When
        val manifest = parseDiffManifest(json)

        // Then
        assertEquals(1, manifest.version)
        assertEquals(listOf("stale.js", "old/asset.png"), manifest.deletedFiles)
        assertTrue(manifest.patchedFiles.isEmpty())
    }

    @Test
    fun parseDiffManifest_missingDeletedFiles_defaultsToEmptyList() {
        // Given
        val json = JSONObject()

        // When
        val manifest = parseDiffManifest(json)

        // Then
        assertEquals(1, manifest.version)
        assertTrue(manifest.deletedFiles.isEmpty())
        assertTrue(manifest.patchedFiles.isEmpty())
    }

    @Test
    fun parseDiffManifest_v2Shape_parsesMultiplePatchedFilesEntries() {
        // Given
        val json = JSONObject(
            """
            {
              "version": 2,
              "deletedFiles": ["removed.js"],
              "patchedFiles": {
                "relative/path.js": {
                  "algo": "bsdiff",
                  "baseHash": "base-hash-1",
                  "targetHash": "target-hash-1",
                  "patch": "__hcp_patches/relative/path.js"
                },
                "another/file.js": {
                  "algo": "bsdiff",
                  "baseHash": "base-hash-2",
                  "targetHash": "target-hash-2",
                  "patch": "__hcp_patches/another/file.js"
                }
              }
            }
            """.trimIndent()
        )

        // When
        val manifest = parseDiffManifest(json)

        // Then
        assertEquals(2, manifest.version)
        assertEquals(listOf("removed.js"), manifest.deletedFiles)
        assertEquals(2, manifest.patchedFiles.size)
        assertEquals(
            PatchedFileEntry(
                algo = "bsdiff",
                baseHash = "base-hash-1",
                targetHash = "target-hash-1",
                patch = "__hcp_patches/relative/path.js",
            ),
            manifest.patchedFiles["relative/path.js"],
        )
        assertEquals(
            PatchedFileEntry(
                algo = "bsdiff",
                baseHash = "base-hash-2",
                targetHash = "target-hash-2",
                patch = "__hcp_patches/another/file.js",
            ),
            manifest.patchedFiles["another/file.js"],
        )
    }

    @Test
    fun parseDiffManifest_missingPatchedFiles_defaultsToEmptyMap() {
        // Given
        val json = JSONObject().put("version", 2).put("deletedFiles", org.json.JSONArray())

        // When
        val manifest = parseDiffManifest(json)

        // Then
        assertEquals(2, manifest.version)
        assertTrue(manifest.patchedFiles.isEmpty())
    }

    @Test(expected = org.json.JSONException::class)
    fun parseDiffManifest_v1ShapeWithPatchedFiles_throws() {
        // Given
        val json = JSONObject(
            """
            {
              "version": 1,
              "patchedFiles": {
                "relative/path.js": {
                  "algo": "bsdiff",
                  "baseHash": "base-hash-1",
                  "targetHash": "target-hash-1",
                  "patch": "__hcp_patches/relative/path.js"
                }
              }
            }
            """.trimIndent()
        )

        // When / Then (parseDiffManifest is expected to throw)
        parseDiffManifest(json)
    }

    @Test(expected = org.json.JSONException::class)
    fun parseDiffManifest_patchedFileEntryMissingRequiredField_throws() {
        // Given
        val json = JSONObject(
            """
            {
              "version": 2,
              "patchedFiles": {
                "relative/path.js": {
                  "algo": "bsdiff",
                  "baseHash": "base-hash-1"
                }
              }
            }
            """.trimIndent()
        )

        // When / Then (parseDiffManifest is expected to throw)
        parseDiffManifest(json)
    }
}
