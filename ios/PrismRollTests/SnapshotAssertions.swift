#if canImport(UIKit)
import SnapshotTesting
import UIKit
import XCTest

@MainActor
enum SnapshotAssertions {
    static let referenceSystemVersion = "26.1"
    static let referenceSystemBuild = "23B86"
    static let referenceModelIdentifier = "iPhone18,1"

    // The direct byte comparison tolerates 0.1% differing color-channel bytes.
    // Avoid Core Image perceptual comparisons: transparent SceneKit PNGs can
    // report broad color changes even when only 1-5 pixels differ by rounding.
    static let imageStrategy: Snapshotting<UIImage, UIImage> = .image(
        precision: 0.999, scale: 1
    )

    static func requireReferenceEnvironment() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["SIMULATOR_MODEL_IDENTIFIER"] == referenceModelIdentifier,
                          "Image baselines require the iPhone 17 Pro simulator; see SNAPSHOT_TESTING.md.")
        try XCTSkipUnless(UIDevice.current.systemVersion == referenceSystemVersion,
                          "Image baselines require iOS \(referenceSystemVersion); see SNAPSHOT_TESTING.md.")
        try XCTSkipUnless(ProcessInfo.processInfo.operatingSystemVersionString.contains(referenceSystemBuild),
                          "Image baselines require runtime build \(referenceSystemBuild); see SNAPSHOT_TESTING.md.")
    }

    static func assertImage(
        _ image: UIImage,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let recording = ProcessInfo.processInfo.environment["PRISM_RECORD_SNAPSHOTS"] == "1"
        assertSnapshot(of: image, as: imageStrategy, named: name,
                       record: recording ? .all : .never, file: file, testName: testName, line: line)
    }
}
#endif
