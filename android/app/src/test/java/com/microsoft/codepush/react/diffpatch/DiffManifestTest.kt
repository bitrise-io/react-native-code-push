package com.microsoft.codepush.react.diffpatch

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
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

    private fun assertPatchFieldRejectedByParser(patch: String) {
        // Given
        val json = JSONObject(
            """
            {
              "version": 2,
              "patchedFiles": {
                "relative/path.js": {
                  "algo": "bsdiff",
                  "baseHash": "base-hash-1",
                  "targetHash": "target-hash-1",
                  "patch": "$patch"
                }
              }
            }
            """.trimIndent()
        )

        // When / Then
        try {
            parseDiffManifest(json)
            fail("expected JSONException")
        } catch (e: org.json.JSONException) {
            assertTrue(e.message, e.message!!.contains("__hcp_patches/"))
        }
    }

    private fun manifestWithPatchedFileKey(relativePath: String) = JSONObject().apply {
        put("version", 2)
        put("patchedFiles", JSONObject().apply {
            put(relativePath, JSONObject().apply {
                put("algo", "bsdiff")
                put("baseHash", "base-hash-1")
                put("targetHash", "target-hash-1")
                put("patch", "__hcp_patches/relative/path.js.bsdiff")
            })
        })
    }

    @Test
    fun parseDiffManifest_patchedFileKeyResolvingIntoReservedFolder_throws() {
        val keys = listOf(
            "__hcp_patches",
            "__hcp_patches/",
            "__hcp_patches/relative/path.js",
            "./__hcp_patches/relative/path.js",
            "/__hcp_patches/relative/path.js",
        )
        for (key in keys) {
            try {
                parseDiffManifest(manifestWithPatchedFileKey(key))
                fail("expected JSONException for key \"$key\"")
            } catch (e: org.json.JSONException) {
                assertTrue(e.message, e.message!!.contains("reserved \"__hcp_patches/\" folder"))
            }
        }
    }

    @Test
    fun parseDiffManifest_patchedFileKeyOutsideReservedFolder_isAccepted() {
        val keys = listOf(
            "assets/__hcp_patches/path.js",
            "__hcp_patches_extra/path.js",
        )
        for (key in keys) {
            val manifest = parseDiffManifest(manifestWithPatchedFileKey(key))
            assertEquals(setOf(key), manifest.patchedFiles.keys)
        }
    }

    @Test
    fun parseDiffManifest_patchedFileKeyWithParentComponent_throws() {
        val keys = listOf(
            "relative/../__hcp_patches/path.js",
            "__hcp_patches/../relative/path.js",
            "relative/../path.js",
            "../path.js",
            "relative/..",
        )
        for (key in keys) {
            try {
                parseDiffManifest(manifestWithPatchedFileKey(key))
                fail("expected JSONException for key \"$key\"")
            } catch (e: org.json.JSONException) {
                assertTrue(e.message, e.message!!.contains("must not contain \"..\" components"))
            }
        }
    }

    @Test
    fun parseDiffManifest_patchedFileKeyWithDotsInComponentName_isAccepted() {
        val keys = listOf("relative/..path.js", "relative/path..js", "...")
        for (key in keys) {
            val manifest = parseDiffManifest(manifestWithPatchedFileKey(key))
            assertEquals(setOf(key), manifest.patchedFiles.keys)
        }
    }

    @Test
    fun parseDiffManifest_patchedFileEntryPatchOutsideReservedPrefix_throws() {
        assertPatchFieldRejectedByParser("relative/path.js.bsdiff")
    }

    @Test
    fun parseDiffManifest_patchedFileEntryPatchWithPrefixButNoSlash_throws() {
        assertPatchFieldRejectedByParser("__hcp_patchesX/relative/path.js.bsdiff")
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
