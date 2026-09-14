# Vendored sources

Note: `shared/third_party/` also contains vendored sources, shared between Android and iOS.

## bzip2/

Source: https://github.com/sisong/bzip2 (referenced directly by HDiffPatch)
Pinned commit: `fbc4b11da543753b3b803e5546f56e26ec90c2a7` (2024-04-09)
License: bzip2 license, a permissive BSD-style license.

Classic bsdiff patches compress their control/diff/extra streams with
bzip2, so `BZ2_bzDecompress*` is needed to read them back. We only ever call
the decompress-side API. The `bzip2`/`bzip2recover` CLI sources are
unrelated to the library API and were not copied. Neither are the
compress-only `compress.c` and `blocksort.c`: after the local patch below,
nothing in the link references `BZ2_compressBlock`/`BZ2_blockSort`.

### Local patch: compress-side code excluded from `bzlib.c`

`bzlib.c` bundles both `BZ2_bzCompress*` and `BZ2_bzDecompress*` in one
file with no split, so an unpatched `bzlib.c` makes the linker demand
`compress.c`/`blocksort.c` for any binary that links it at all, even one
that never calls the compress-side API.

Measured impact of removing it: 118,528 B → 79,792 B (arm64-v8a)

**What was changed, precisely**, to make a future bzip2 version bump easier:
- In `bzlib.c`, wrapped in `#ifndef BZ_NO_COMPRESS` / `#endif`:
  - Compress-only static helpers: `prepare_new_block`, `init_RL`, `isempty_RL`
  - The streaming compress API and its private
    helpers: `BZ2_bzCompressInit`, `add_pair_to_block`, `flush_RL`, the
    `ADD_CHAR_TO_BLOCK` macro, `copy_input_until_stop`,
    `copy_output_until_stop`, `handle_compress`, `BZ2_bzCompress`,
    `BZ2_bzCompressEnd`
  - The buffer-to-buffer compress convenience wrapper: `BZ2_bzBuffToBuffCompress`
- `CMakeLists.txt` defines `BZ_NO_STDIO=1`, a pre-existing upstream switch that excludes
  the whole `FILE*`-based `bzopen`/`bzread`/`bzwrite` API, which also calls the now-excluded
  compress functions. `BZ_NO_STDIO` requires the embedder to supply
  `bz_internal_error()`; see `../bzip2_error_stub.c`.
