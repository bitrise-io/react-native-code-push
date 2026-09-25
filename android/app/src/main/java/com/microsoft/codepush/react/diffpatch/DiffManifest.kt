package com.microsoft.codepush.react.diffpatch

import com.microsoft.codepush.react.CodePushConstants
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
) {
    // True if this manifest describes a binary diff update, which ships its patches under CodePushConstants.DIFF_PATCHES_FOLDER_NAME.
    // This is a subset of "diff updates" in general, as a diff update payload can also consist of:
    // - The modified files included in the ZIP, which are applied on top of the existing files (without any binary patching)
    // - The list of files to delete from the old package
    val isBinaryDiff: Boolean
        get() = version == 2
}

@Throws(JSONException::class)
fun parseDiffManifest(json: JSONObject): DiffManifest {
    val version = if (json.has("version")) json.getInt("version") else 1

    val deletedFilesJson = json.optJSONArray("deletedFiles")
    val deletedFiles = if (deletedFilesJson != null) {
        (0 until deletedFilesJson.length()).map { deletedFilesJson.getString(it) }
    } else {
        emptyList()
    }

    val reservedPatchesFolderPrefix = "${CodePushConstants.DIFF_PATCHES_FOLDER_NAME}/"
    val patchedFilesJson = json.optJSONObject("patchedFiles")
    val patchedFiles = if (patchedFilesJson != null) {
        patchedFilesJson.keys().asSequence().associateWith { relativePath ->
            if (relativePath.split('/').contains("..")) {
                throw JSONException("Diff manifest patchedFiles[\"$relativePath\"] must not contain \"..\" components.")
            }
            if (topLevelComponentOf(relativePath) == CodePushConstants.DIFF_PATCHES_FOLDER_NAME) {
                throw JSONException("Diff manifest patchedFiles[\"$relativePath\"] targets the reserved \"$reservedPatchesFolderPrefix\" folder, which is not part of the installed package.")
            }
            val entry = patchedFilesJson.getJSONObject(relativePath)
            val patch = entry.getString("patch")
            if (!patch.startsWith(reservedPatchesFolderPrefix)) {
                throw JSONException("Diff manifest patchedFiles[\"$relativePath\"] field \"patch\" must be under the reserved \"$reservedPatchesFolderPrefix\" prefix, but is \"$patch\".")
            }
            PatchedFileEntry(
                algo = entry.getString("algo"),
                baseHash = entry.getString("baseHash"),
                targetHash = entry.getString("targetHash"),
                patch = patch,
            )
        }
    } else {
        emptyMap()
    }

    val manifest = DiffManifest(version = version, deletedFiles = deletedFiles, patchedFiles = patchedFiles)
    if (!manifest.isBinaryDiff && patchedFiles.isNotEmpty()) {
        throw JSONException("Diff manifest declares version $version but contains patchedFiles, which requires version 2.")
    }

    return manifest
}

// The top-level entry that `relativePath` names under a base folder. Empty and "." components are skipped.
// The caller rejects ".." components first, so they need no handling here.
private fun topLevelComponentOf(relativePath: String): String? =
    relativePath.split('/').firstOrNull { it.isNotEmpty() && it != "." }
