#if os(iOS) || os(tvOS) || os(macOS)
  import CoreGraphics
  import XCTest

  @testable import SnapshotTesting

  #if os(macOS)
    import AppKit
    typealias PlatformImage = NSImage
  #else
    import UIKit
    typealias PlatformImage = UIImage
  #endif

  final class ImageDiffPrecisionTests: XCTestCase {
    // 400x300 px with a 40x30 px block repainted: 1% of the pixels and 0.75% of the bytes differ
    // (the alpha channel doesn't change).
    func testPrecisionDiffingFailsWhenTooManyBytesDiffer() {
      let (reference, snapshot) = images()
      for precision: Float in [1, 0.999, 0.995] {
        let failure = Diffing<PlatformImage>.image(precision: precision).diff(reference, snapshot)
        XCTAssertNotNil(failure, "precision \(precision)")
      }
    }

    func testPrecisionDiffingPassesWhenFewEnoughBytesDiffer() {
      let (reference, snapshot) = images()
      for precision: Float in [0.99, 0.9] {
        let failure = Diffing<PlatformImage>.image(precision: precision).diff(reference, snapshot)
        XCTAssertNil(failure, "precision \(precision)")
      }
    }

    private func images() -> (reference: PlatformImage, snapshot: PlatformImage) {
      func render(changed: Bool) -> CGImage {
        let context = CGContext(
          data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        if changed {
          context.setFillColor(CGColor(srgbRed: 0.9, green: 0.1, blue: 0.3, alpha: 1))
          context.fill(CGRect(x: 100, y: 100, width: 40, height: 30))
        }
        return context.makeImage()!
      }
      let diffing = Diffing<PlatformImage>.image
      #if os(macOS)
        let reference = NSImage(cgImage: render(changed: false), size: NSSize(width: 400, height: 300))
        let snapshot = NSImage(cgImage: render(changed: true), size: NSSize(width: 400, height: 300))
      #else
        let reference = UIImage(cgImage: render(changed: false), scale: 1, orientation: .up)
        let snapshot = UIImage(cgImage: render(changed: true), scale: 1, orientation: .up)
      #endif
      // Load the reference back from PNG data, as it would be from disk.
      return (diffing.fromData(diffing.toData(reference)), snapshot)
    }
  }
#endif
