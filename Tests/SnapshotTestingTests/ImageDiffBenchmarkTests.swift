import Foundation
import XCTest

@testable import SnapshotTesting

#if canImport(UIKit)
  import UIKit
#endif

final class ImageDiffBenchmarkTests: XCTestCase {
  // An iPhone-sized screenshot at 3x: 1179x2556 RGBA.
  static let width = 1179
  static let height = 2556
  static let byteCount = width * height * 4

  func testCountDifferingBytesMatchesNaiveCount() {
    var generator = SystemRandomNumberGenerator()
    for length in Array(0...257) + [4096, 4099, 100_003] {
      let old = (0..<length).map { _ in UInt8.random(in: 0...3, using: &generator) }
      let new = (0..<length).map { _ in UInt8.random(in: 0...3, using: &generator) }
      let expected = zip(old, new).filter { $0 != $1 }.count
      XCTAssertEqual(countDifferingBytes(old, new), expected, "length \(length)")
    }
    let all = [UInt8](repeating: 0, count: 1000)
    XCTAssertEqual(countDifferingBytes(all, [UInt8](repeating: 0xFF, count: 1000)), 1000)
    XCTAssertEqual(countDifferingBytes(all, all), 0)
    // Long enough to overflow 8-bit counters if they weren't flushed.
    let long = [UInt8](repeating: 0, count: 64 * 255 * 3 + 5)
    XCTAssertEqual(countDifferingBytes(long, long.map { $0 &+ 1 }), long.count)
  }

  func testCountDifferingBytesAtUnalignedOffsets() {
    var generator = SystemRandomNumberGenerator()
    let old = (0..<1024).map { _ in UInt8.random(in: 0...3, using: &generator) }
    let new = (0..<1024).map { _ in UInt8.random(in: 0...3, using: &generator) }
    old.withUnsafeBytes { old in
      new.withUnsafeBytes { new in
        for oldOffset in 0..<16 {
          for newOffset in 0..<16 {
            let length = 1000 - oldOffset - newOffset
            let expected = zip(old[oldOffset...].prefix(length), new[newOffset...].prefix(length))
              .filter { $0 != $1 }.count
            let oldStart = old.baseAddress! + oldOffset
            let newStart = new.baseAddress! + newOffset
            XCTAssertEqual(
              countDifferingBytes(oldStart, newStart, count: length),
              expected,
              "offsets \(oldOffset), \(newOffset)"
            )
            XCTAssertEqual(
              countDifferingBytesByWord(oldStart, newStart, count: length),
              expected,
              "word fallback, offsets \(oldOffset), \(newOffset)"
            )
          }
        }
      }
    }
  }

  func testBenchmarkCountDifferingBytes() throws {
    try skipUnlessBenchmarking()
    let old = [UInt8](repeating: 0, count: Self.byteCount)

    var smallRegion = old
    for y in 1000..<1100 {
      for x in 400..<600 {
        for c in 0..<4 { smallRegion[(y * Self.width + x) * 4 + c] = 1 }
      }
    }
    let allDifferent = [UInt8](repeating: 1, count: Self.byteCount)

    report("countDifferingBytes, 200x100 px differ") {
      XCTAssertEqual(countDifferingBytes(old, smallRegion), 80_000)
    }
    report("countDifferingBytes, every byte differs") {
      XCTAssertEqual(countDifferingBytes(old, allDifferent), Self.byteCount)
    }
  }

  #if os(iOS) || os(tvOS)
    func testBenchmarkImageDiffing() throws {
      try skipUnlessBenchmarking()
      let size = CGSize(width: Self.width / 3, height: Self.height / 3)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 3
      func render(highlight: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: size, format: format).image { context in
          for row in 0..<Int(size.height / 20) {
            UIColor(hue: CGFloat(row % 12) / 12, saturation: 0.6, brightness: 0.9, alpha: 1)
              .setFill()
            context.fill(CGRect(x: 0, y: row * 20, width: Int(size.width), height: 20))
            ("Row \(row)" as NSString).draw(
              at: CGPoint(x: 8, y: row * 20 + 2),
              withAttributes: [.font: UIFont.systemFont(ofSize: 14)]
            )
          }
          if highlight {
            UIColor.black.setFill()
            context.fill(CGRect(x: 133, y: 333, width: 67, height: 34))
          }
        }
      }
      let reference = UIImage(data: render(highlight: false).pngData()!, scale: 3)!
      let snapshot = render(highlight: true)
      let diffing = Diffing<UIImage>.image(precision: 0.99)

      report("Diffing.image(precision: 0.99), end to end") {
        XCTAssertNil(diffing.diff(reference, snapshot))
      }
    }
  #endif

  private func skipUnlessBenchmarking() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["SNAPSHOT_BENCHMARKS"] != nil,
      "Set SNAPSHOT_BENCHMARKS=1 to run benchmarks."
    )
  }

  private func report(_ name: String, iterations: Int = 10, _ body: () -> Void) {
    body()  // Warm up.
    var samples: [Double] = []
    for _ in 0..<iterations {
      let start = DispatchTime.now().uptimeNanoseconds
      body()
      samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }
    samples.sort()
    print(
      String(
        format: "[BENCH] %@: median %.2f ms, min %.2f ms, max %.2f ms",
        name, samples[samples.count / 2], samples[0], samples[samples.count - 1]
      )
    )
  }
}
