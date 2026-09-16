#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class SnapshotRegressionTests: XCTestCase {
    func testTutorialAtStandardAndAccessibilityTextSizes() throws {
        try SnapshotAssertions.requireReferenceEnvironment()
        for (name, size) in [("standard", DynamicTypeSize.large), ("accessibility", .accessibility3)] {
            let content = TutorialTipView(hasMoved: false, instruction: nil, onDismiss: {})
                .padding(16)
                .frame(width: 360)
                .foregroundStyle(Palette.ink)
                .background(Palette.background)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 1
            renderer.isOpaque = true
            SnapshotAssertions.assertImage(try XCTUnwrap(renderer.uiImage), named: name)
        }
    }

    func testVisibleImageRegressionFailsWithoutReplacingReference() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format)
        let reference = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        let changed = renderer.image { context in
            reference.draw(at: .zero)
            UIColor.white.setFill()
            context.fill(CGRect(x: 24, y: 24, width: 8, height: 8))
        }
        let baselineURL = directory.appendingPathComponent("guardrail.baseline.png")
        let baselineData = try XCTUnwrap(reference.pngData())
        try baselineData.write(to: baselineURL)

        func verify(_ image: UIImage, named name: String = "baseline") -> String? {
            verifySnapshot(of: image, as: SnapshotAssertions.imageStrategy, named: name,
                           record: .never, snapshotDirectory: directory.path, testName: "guardrail")
        }

        XCTAssertNil(verify(reference), "An unchanged image must pass.")
        XCTAssertNotNil(verify(changed), "An 8 x 8 visible change must fail at the production tolerance.")
        XCTAssertEqual(try Data(contentsOf: baselineURL), baselineData,
                       "A failed comparison must not overwrite its approved reference.")
        XCTAssertNotNil(verify(reference, named: "missing"), "A missing baseline must fail.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("guardrail.missing.png").path),
                       "Normal test runs must never create missing baselines.")
    }
}
#endif
