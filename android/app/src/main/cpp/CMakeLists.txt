cmake_minimum_required(VERSION 3.22.1)
# C only for now, to keep libc++ and its bundle size out of the build.
# Vendored code is all in C, and our glue code is simple enough to be written in C,
# but this might need to be revisited in the future.
project(codepush_diffpatch C)

# Single shared library:
# - vendored HDiffPatch (bsdiff-compatible patch applier only)
# - vendored bzip2
# - our bridge from the HDiffPatch C API to the JNI layer
# - JNI glue
# See third_party/README.md for what we vendor and why.
add_library(codepush_diffpatch SHARED
        diffpatch_jni.c
        ../../../../../shared/diffpatch/bspatch_bridge.c

        ../../../../../shared/third_party/hdiffpatch/libHDiffPatch/HPatch/patch.c
        ../../../../../shared/third_party/hdiffpatch/bsdiff_wrapper/bspatch_wrapper.c
        ../../../../../shared/third_party/hdiffpatch/file_for_patch.c

        bzip2_error_stub.c
        third_party/bzip2/bzlib.c
        third_party/bzip2/decompress.c
        third_party/bzip2/huffman.c
        third_party/bzip2/crctable.c
        third_party/bzip2/randtable.c
)

target_include_directories(codepush_diffpatch PRIVATE
        .
        ../../../../../shared/diffpatch
        ../../../../../shared
        third_party/bzip2
)

target_compile_definitions(codepush_diffpatch PRIVATE
        # We only ever patch regular files under app-private storage, never
        # raw block devices. Skip file_for_patch.c's block-device probing
        # (avoids depending on <linux/fs.h> ioctls entirely).
        _IS_NEED_BLOCK_DEV=0

        # Defaults to 1, which pulls in hpatch_mt/*.h files.
        # Not needed for our use case.
        _IS_USED_MULTITHREAD=0

        # Defaults 1, which compiles in hpatch_removeDir/hpatch_moveFile/hpatch_makeNewDir
        # We only ever patch a single regular file.
        _IS_NEED_DIR_DIFF_PATCH=0

        # We only ever use bzip's decompression API.
        # See third_party/README.md for details.
        BZ_NO_COMPRESS=1
        BZ_NO_STDIO=1
)

# HDiffPatch uses <android/log.h>
target_link_libraries(codepush_diffpatch log)
