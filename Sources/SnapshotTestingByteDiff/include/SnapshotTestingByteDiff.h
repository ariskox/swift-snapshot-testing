#ifndef SNAPSHOT_TESTING_BYTE_DIFF_H
#define SNAPSHOT_TESTING_BYTE_DIFF_H

#include <stddef.h>
#include <stdint.h>

#if defined(__ARM_NEON)
/// Returns the number of bytes that differ between the first `count` bytes of two buffers, using
/// NEON vector instructions. Intrinsics compile to vector instructions even without optimizations,
/// so this stays fast in debug builds.
size_t snapshot_testing_count_differing_bytes_neon(
    const uint8_t *_Nonnull old, const uint8_t *_Nonnull new_, size_t count);
#endif

#endif
