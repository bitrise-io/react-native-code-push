#include <jni.h>

#include "bspatch_bridge.h"

JNIEXPORT jint JNICALL
Java_com_microsoft_codepush_react_diffpatch_DiffPatch_nativeBSPatchApply(
        JNIEnv* env, jclass clazz,
        jstring oldFilePath, jstring diffFilePath, jstring outNewFilePath) {
    const char* oldPath;
    const char* diffPath;
    const char* outPath;
    CodePushBSPatchResult result;

    (void)clazz;

    oldPath = (*env)->GetStringUTFChars(env, oldFilePath, NULL);
    if (oldPath == NULL) {
        return (jint)CODEPUSH_BSPATCH_ERR_OOM;
    }

    diffPath = (*env)->GetStringUTFChars(env, diffFilePath, NULL);
    if (diffPath == NULL) {
        (*env)->ReleaseStringUTFChars(env, oldFilePath, oldPath);
        return (jint)CODEPUSH_BSPATCH_ERR_OOM;
    }

    outPath = (*env)->GetStringUTFChars(env, outNewFilePath, NULL);
    if (outPath == NULL) {
        (*env)->ReleaseStringUTFChars(env, oldFilePath, oldPath);
        (*env)->ReleaseStringUTFChars(env, diffFilePath, diffPath);
        return (jint)CODEPUSH_BSPATCH_ERR_OOM;
    }

    result = codepush_bspatch_apply(oldPath, diffPath, outPath);

    (*env)->ReleaseStringUTFChars(env, oldFilePath, oldPath);
    (*env)->ReleaseStringUTFChars(env, diffFilePath, diffPath);
    (*env)->ReleaseStringUTFChars(env, outNewFilePath, outPath);

    return (jint)result;
}
