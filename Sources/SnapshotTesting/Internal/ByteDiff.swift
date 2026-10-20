import SnapshotTestingByteDiff

/// Returns the number of bytes that differ between two equally sized byte buffers.
func countDifferingBytes(_ old: [UInt8], _ new: [UInt8]) -> Int {
  precondition(old.count == new.count)
  return old.withUnsafeBytes { oldBytes in
    new.withUnsafeBytes { newBytes in
      guard let old = oldBytes.baseAddress, let new = newBytes.baseAddress else { return 0 }
      return countDifferingBytes(old, new, count: oldBytes.count)
    }
  }
}

/// Returns the number of bytes that differ between the first `count` bytes of two buffers.
func countDifferingBytes(_ old: UnsafeRawPointer, _ new: UnsafeRawPointer, count: Int) -> Int {
  #if arch(arm64)
    return snapshot_testing_count_differing_bytes_neon(
      old.assumingMemoryBound(to: UInt8.self),
      new.assumingMemoryBound(to: UInt8.self),
      count
    )
  #else
    return countDifferingBytesByWord(old, new, count: count)
  #endif
}

/// The portable fallback for `countDifferingBytes(_:_:count:)` on CPUs without NEON.
func countDifferingBytesByWord(_ old: UnsafeRawPointer, _ new: UnsafeRawPointer, count: Int) -> Int
{
  // NB: Raw pointers avoid the bounds and uniqueness checks that `Array` subscripts perform when
  //     the compiler doesn't have optimizations enabled, like in test targets. Comparing 8 bytes
  //     per iteration cuts the number of (unoptimized) loop iterations by 8.
  let wordSize = MemoryLayout<UInt64>.size
  let wordCount = count / wordSize
  var differentByteCount = 0
  var offset = 0
  var word = 0
  while word < wordCount {
    let difference =
      old.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
      ^ new.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
    if difference != 0 {
      differentByteCount += differingByteCount(difference)
    }
    offset += wordSize
    word += 1
  }
  while offset < count {
    if old.load(fromByteOffset: offset, as: UInt8.self)
      != new.load(fromByteOffset: offset, as: UInt8.self)
    {
      differentByteCount += 1
    }
    offset += 1
  }
  return differentByteCount
}

/// Returns the number of non-zero bytes in `word`.
@inline(__always)
private func differingByteCount(_ word: UInt64) -> Int {
  // Sets the high bit of every non-zero byte without letting carries cross byte boundaries.
  let lowBits: UInt64 = 0x7F7F_7F7F_7F7F_7F7F
  return ((((word & lowBits) &+ lowBits) | word) & ~lowBits).nonzeroBitCount
}
