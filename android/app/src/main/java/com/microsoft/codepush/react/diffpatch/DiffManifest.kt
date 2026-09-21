package com.microsoft.codepush.react.diffpatch

import org.json.JSONException
import org.json.JSONObject

data class PatchedFileEntry(
    // The only value this client understands at the moment is "bsdiff".
    val algo: String,
    // SHA-256 hex of the file's content in the currently installed package
    // Should be checked before patching.
    val baseHash: String,
    // SHA-256 hex the patched output must match, should be checked after patching.
    val targetHash: String,
    // Zip-relative path to the patch file, under the reserved prefix (CodePushConstants.DIFF_PATCHES_FOLDER_NAME).
    val patch: String,
)

data class DiffManifest(
    // No version field, or version 1: original format, file-by-file patching only.
    // Version 2: adds support for binary diff patching.
    val version: Int,
    // Relative paths, from the old package, to delete rather than carry over into the new one.
    val deletedFiles: List<String>,
    // Map key: file's relative path in the package being installed.
    val patchedFiles: Map<String, PatchedFileEntry>,
)

@Throws(JSONException::class)
fun parseDiffManifest(json: JSONObject): DiffManifest {
    val version = if (json.has("version")) json.getInt("version") else 1

    val deletedFilesJson = json.optJSONArray("deletedFiles")
    val deletedFiles = if (deletedFilesJson != null) {
        (0 until deletedFilesJson.length()).map { deletedFilesJson.getString(it) }
    } else {
        emptyList()
    }

    val patchedFilesJson = json.optJSONObject("patchedFiles")
    val patchedFiles = if (patchedFilesJson != null) {
        patchedFilesJson.keys().asSequence().associateWith { relativePath ->
            val entry = patchedFilesJson.getJSONObject(relativePath)
            PatchedFileEntry(
                algo = entry.getString("algo"),
                baseHash = entry.getString("baseHash"),
                targetHash = entry.getString("targetHash"),
                patch = entry.getString("patch"),
            )
        }
    } else {
        emptyMap()
    }

    if (version != 2 && patchedFiles.isNotEmpty()) {
        throw JSONException("Diff manifest declares version $version but contains patchedFiles, which requires version 2.")
    }

    return DiffManifest(version = version, deletedFiles = deletedFiles, patchedFiles = patchedFiles)
}
