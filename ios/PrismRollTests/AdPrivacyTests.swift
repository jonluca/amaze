#if canImport(GoogleMobileAds)
import GoogleMobileAds
import XCTest
@testable import PrismRoll

@MainActor
final class AdPrivacyTests: XCTestCase {
    func testNonPersonalizedSignalSurvivesSDKRequestCopy() throws {
        let request = AdConfiguration.makeRequest()
        let copied = try XCTUnwrap(request.copy() as? Request)
        let extras = try XCTUnwrap(copied.adNetworkExtras(for: Extras.self) as? Extras)
        XCTAssertEqual(extras.additionalParameters?["npa"] as? String, "1")
        XCTAssertNil(copied.contentURL)
        XCTAssertNil(copied.keywords)
    }
}
#endif
