# Vendored sources

Vendored libraries shared across native iOS and Android modules.

## hdiffpatch/

Source: https://github.com/sisong/HDiffPatch
Pinned commit: `3b9dca715ca492873bf2c49e22e5d5b7d2a78620` (2026-07-31)
License: MIT.

Files were chosen by tracing the actual dependency graph of
`bsdiff_wrapper/bspatch_wrapper.c` (the BSDIFF40-compatible patch applier),
not by directory boundaries. In particular `libHDiffPatch/HPatch/patch.c`
(~157KB) is HDiffPatch's own diff-format decoder, but it's still required
here because `bspatch_wrapper.c` shares its low-level stream-cache helpers
(`_TOutStreamCache_*`, `getStreamClip`, `_patch_cache_all_old`, etc.).
