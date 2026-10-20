/// Returns the number of bytes that differ between two equally sized byte buffers.
func countDifferingBytes(_ old: [UInt8], _ new: [UInt8]) -> Int {
  precondition(old.count == new.count)
  var differentByteCount = 0
  // NB: We are purposely using a verbose 'while' loop instead of a 'for in' loop.  When the
  //     compiler doesn't have optimizations enabled, like in test targets, a `while` loop is
  //     significantly faster than a `for` loop for iterating through the elements of a memory
  //     buffer. Details can be found in [SR-6983](https://github.com/apple/swift/issues/49531)
  var index = 0
  while index < old.count {
    defer { index += 1 }
    if old[index] != new[index] {
      differentByteCount += 1
    }
  }
  return differentByteCount
}
