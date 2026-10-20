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
  // NB: Raw pointers avoid the bounds and uniqueness checks that `Array` subscripts perform when
  //     the compiler doesn't have optimizations enabled, like in test targets.
  let old = old.assumingMemoryBound(to: UInt8.self)
  let new = new.assumingMemoryBound(to: UInt8.self)
  var differentByteCount = 0
  var index = 0
  while index < count {
    if old[index] != new[index] {
      differentByteCount += 1
    }
    index += 1
  }
  return differentByteCount
}
