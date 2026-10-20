#include "SnapshotTestingByteDiff.h"

#if defined(__ARM_NEON)
#include <arm_neon.h>

size_t snapshot_testing_count_differing_bytes_neon(
    const uint8_t *_Nonnull old, const uint8_t *_Nonnull new_, size_t count) {
  size_t total = 0;
  size_t offset = 0;
  // Each lane of the accumulators counts up to 255 differences, so they are flushed into `total`
  // every 255 iterations at the latest.
  while (offset + 64 <= count) {
    uint8x16_t counts0 = vdupq_n_u8(0);
    uint8x16_t counts1 = vdupq_n_u8(0);
    uint8x16_t counts2 = vdupq_n_u8(0);
    uint8x16_t counts3 = vdupq_n_u8(0);
    for (int iteration = 0; iteration < 255 && offset + 64 <= count; iteration++, offset += 64) {
      // vceqq_u8 yields 0xFF for equal lanes; subtracting the inverted mask adds 1 per difference.
      counts0 = vsubq_u8(counts0, vmvnq_u8(vceqq_u8(vld1q_u8(old + offset), vld1q_u8(new_ + offset))));
      counts1 = vsubq_u8(
          counts1, vmvnq_u8(vceqq_u8(vld1q_u8(old + offset + 16), vld1q_u8(new_ + offset + 16))));
      counts2 = vsubq_u8(
          counts2, vmvnq_u8(vceqq_u8(vld1q_u8(old + offset + 32), vld1q_u8(new_ + offset + 32))));
      counts3 = vsubq_u8(
          counts3, vmvnq_u8(vceqq_u8(vld1q_u8(old + offset + 48), vld1q_u8(new_ + offset + 48))));
    }
    total += vaddlvq_u8(counts0) + vaddlvq_u8(counts1) + vaddlvq_u8(counts2) + vaddlvq_u8(counts3);
  }
  for (; offset < count; offset++) {
    if (old[offset] != new_[offset]) {
      total++;
    }
  }
  return total;
}
#endif
