// bzlib_private.h requires the embedder to supply bz_internal_error()
// whenever BZ_NO_STDIO is defined (see third_party/bzip2/bzlib_private.h
// and third_party/README.md) - upstream's non-stdio build normally
// leaves this fprintf/exit(3) to the caller. It's only ever reached on
// an internal bzip2 consistency-check failure (a corrupt/malicious
// bzip2 stream), which should abort the patch operation immediately
// rather than continue with undefined state.
#include <stdlib.h>

void bz_internal_error(int errcode) {
    abort();
}
