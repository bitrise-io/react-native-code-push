// Thin wrapper around HDiffPatch's BSDIFF40 patch applier.
// The declarations below are C-linkage/C-callable.
#ifndef CODEPUSH_BSPATCH_BRIDGE_H
#define CODEPUSH_BSPATCH_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum CodePushBSPatchResult {
    CODEPUSH_BSPATCH_OK = 0,
    CODEPUSH_BSPATCH_ERR_BAD_DIFF_HEADER = 1,
    CODEPUSH_BSPATCH_ERR_OPEN_OLD = 2,
    CODEPUSH_BSPATCH_ERR_OPEN_DIFF = 3,
    CODEPUSH_BSPATCH_ERR_OPEN_OUT = 4,
    CODEPUSH_BSPATCH_ERR_OOM = 5,
    CODEPUSH_BSPATCH_ERR_PATCH_FAILED = 6,
} CodePushBSPatchResult;

// Applies a BSDIFF40-format patch to oldFilePath, writing the result
// to outNewFilePath. All three paths must be plain regular files;
// outNewFilePath is created/truncated, and removed again if patching fails partway through.
CodePushBSPatchResult codepush_bspatch_apply(const char* oldFilePath,
                                             const char* diffFilePath,
                                             const char* outNewFilePath);

#ifdef __cplusplus
}
#endif

#endif // CODEPUSH_BSPATCH_BRIDGE_H
