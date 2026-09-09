#if canImport(GoogleMobileAds)
import GoogleMobileAds
import XCTest
@testable import PrismRoll

@MainActor
final class AdPrivacyTests: XCTestCase {
    func testSoundPreferenceUpdatesSDKBeforeAdPreparation() async {
        let previousMuted = MobileAds.shared.isApplicationMuted
        let ads = AdService(configuration: nil)

        func expectMuted(_ expected: Bool) async {
            let applied = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "applicationMuted == %@", NSNumber(value: expected)),
                object: MobileAds.shared
            )
            await fulfillment(of: [applied], timeout: 3)
        }

        ads.setSoundEnabled(false)
        await expectMuted(true)

        ads.prepare()
        XCTAssertTrue(MobileAds.shared.isApplicationMuted,
                      "Preparing unavailable ads must preserve the app's sound preference")

        ads.setSoundEnabled(true)
        await expectMuted(false)

        MobileAds.shared.isApplicationMuted = previousMuted
        await expectMuted(previousMuted)
    }

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
