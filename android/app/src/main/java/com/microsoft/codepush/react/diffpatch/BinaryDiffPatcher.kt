@file:JvmName("BinaryDiffPatcher")
package com.microsoft.codepush.react.diffpatch

import java.io.File
import java.io.IOException

class BinaryDiffApplyException(val relativePath: String, reason: String) :
    IOException("Failed to apply binary diff patch for \"$relativePath\": $reason")

@JvmOverloads
fun applyBinaryDiffPatches(
    manifest: DiffManifest,
    currentPackageFolder: File,
    unzippedFolder: File,
    newUpdateFolder: File,
    patchApplier: PatchApplier = NativeBsdiffPatchApplier,
) {
    for ((relativePath, entry) in manifest.patchedFiles) {
        if (entry.algo != "bsdiff") {
            throw BinaryDiffApplyException(relativePath, "unsupported patch algorithm: ${entry.algo}")
        }
    }

    for ((relativePath, entry) in manifest.patchedFiles) {
        val oldFile = resolveWithin(currentPackageFolder, relativePath)
        val oldFileHash = sha256Hex(oldFile)
        if (oldFileHash != entry.baseHash) {
            throw BinaryDiffApplyException(relativePath, "baseHash mismatch: expected ${entry.baseHash}, got $oldFileHash")
        }

        val diffFile = resolveWithin(unzippedFolder, entry.patch)
        val newFile = resolveWithin(newUpdateFolder, relativePath).apply { parentFile?.mkdirs() }

        val result = patchApplier.apply(oldFile, diffFile, newFile)
        if (result != DiffPatch.PatchResult.OK) {
            throw BinaryDiffApplyException(relativePath, "patch failed: $result")
        }

        val newFileHash = sha256Hex(newFile)
        if (newFileHash != entry.targetHash) {
            throw BinaryDiffApplyException(relativePath, "targetHash mismatch: expected ${entry.targetHash}, got $newFileHash")
        }
    }
}

// Manifest-supplied paths come from the update's JSON, so we treat them as untrusted.
// Resolve them strictly under `base` and reject anything ("../../etc", an absolute path) that would otherwise
// let a manifest entry read or write outside the package/patch folders. Callers treat the result as a file
// inside `base`, so `base` itself (e.g. from ".") does not pass either.
private fun resolveWithin(base: File, relativePath: String): File {
    val baseCanonical = base.canonicalFile
    val resolved = File(base, relativePath).canonicalFile
    if (!resolved.path.startsWith(baseCanonical.path + File.separator)) {
        throw BinaryDiffApplyException(relativePath, "path escapes expected directory")
    }
    return resolved
}
