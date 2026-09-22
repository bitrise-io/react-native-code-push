#include "bspatch_bridge.h"

#include "third_party/hdiffpatch/libHDiffPatch/HPatch/patch_types.h"
#include "third_party/hdiffpatch/file_for_patch.h"
#include "third_party/hdiffpatch/bsdiff_wrapper/bspatch_wrapper.h"

#define _CompressPlugin_bz2
// Despite the filename, this isn't sample code: it's upstream's only
// definition of _bz2DecompressPlugin_unsz. It's written to be #included
// (not compiled standalone): defining _CompressPlugin_bz2 before including it compiles
// just the bz2 decompressor variant into this translation unit.
#include "third_party/hdiffpatch/decompress_plugin_demo.h"

#include <stdlib.h>

// Clang/GCC's scope-based cleanup instead of `goto`s. (Android NDK uses clang)
#define CLEANUP(fn) __attribute__((cleanup(fn)))

static void freeTempCache(unsigned char** pCache) {
    free(*pCache);
}

// Sliced up internally by bspatch_with_cache between the old-file cache and
// up to three decompression streams.
// Bigger just means fewer read() round-trips.
// TODO: benchmark and fine-tune this.
#define kTempCacheSize ((size_t)1 << 20) // 1 MiB

static CodePushBSPatchResult applyPatchImpl(const char* oldFilePath,
                                            const char* diffFilePath,
                                            const char* outNewFilePath) {
    // Every resource is declared and neutralized here, before the first
    // fallible call: no early return may be introduced inside this block.
    CLEANUP(hpatch_TFileStreamInput_close) hpatch_TFileStreamInput oldStream;
    hpatch_TFileStreamInput_init(&oldStream);
    CLEANUP(hpatch_TFileStreamInput_close) hpatch_TFileStreamInput diffStream;
    hpatch_TFileStreamInput_init(&diffStream);
    CLEANUP(hpatch_TFileStreamOutput_close) hpatch_TFileStreamOutput outStream;
    hpatch_TFileStreamOutput_init(&outStream);
    CLEANUP(freeTempCache) unsigned char* tempCache = NULL;

    hpatch_BsDiffInfo diffInfo;

    if (!hpatch_TFileStreamInput_open(&oldStream, oldFilePath))
        return CODEPUSH_BSPATCH_ERR_OPEN_OLD;
    if (!hpatch_TFileStreamInput_open(&diffStream, diffFilePath))
        return CODEPUSH_BSPATCH_ERR_OPEN_DIFF;

    if (!getBsDiffInfo(&diffInfo, &diffStream.base))
        return CODEPUSH_BSPATCH_ERR_BAD_DIFF_HEADER;

    // Why open the output only at this point: the maxLength param isn't known until the diff header above has been parsed.
    if (!hpatch_TFileStreamOutput_open(&outStream, outNewFilePath, diffInfo.newDataSize))
        return CODEPUSH_BSPATCH_ERR_OPEN_OUT;

    tempCache = (unsigned char*)malloc(kTempCacheSize);
    if (!tempCache) return CODEPUSH_BSPATCH_ERR_OOM;

    // _bz2DecompressPlugin_unsz usage (not the plain bz2DecompressPlugin): bsdiff's
    // three compressed sub-streams are back-to-back in one bzip2 stream
    // without individually recorded output sizes, so the decompressor must
    // tolerate reading past its logical end and zero-fill instead of
    // erroring. That's what the "_unsz" (unknown size) variant does.
    if (!bspatch_with_cache(&outStream.base, &oldStream.base, &diffStream.base,
                            &_bz2DecompressPlugin_unsz,
                            tempCache, tempCache + kTempCacheSize))
        return CODEPUSH_BSPATCH_ERR_PATCH_FAILED;

    // Flush here, so a failing final write (ENOSPC, EIO) is reported instead of
    // leaving a truncated bundle on disk under a success code.
    if (!hpatch_TFileStreamOutput_flush(&outStream))
        return CODEPUSH_BSPATCH_ERR_PATCH_FAILED;

    return CODEPUSH_BSPATCH_OK;
}

CodePushBSPatchResult codepush_bspatch_apply(const char* oldFilePath,
                                             const char* diffFilePath,
                                             const char* outNewFilePath) {
    CodePushBSPatchResult result = applyPatchImpl(oldFilePath, diffFilePath, outNewFilePath);
    if (result != CODEPUSH_BSPATCH_OK) {
        // Don't leave a corrupt, partially-written "new bundle" on disk.
        // It's a no-op when outNewFilePath was never created (e.g. ERR_OPEN_OLD)
        hpatch_removeFile(outNewFilePath);
    }
    return result;
}
