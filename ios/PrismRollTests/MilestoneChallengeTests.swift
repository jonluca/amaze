import XCTest
@testable import PrismRoll

final class MilestoneChallengeTests: XCTestCase {
    func testMilestoneThresholdAndClaimAreIdempotentAcrossRelaunch() throws {
        var progress = ProgressData()
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 0)
        XCTAssertEqual(progress.claimMilestone(id: "missing"), 0)
        for number in 1...4 { progress.completeLevel(.generate(number: number, mode: .endless)) }
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 0)
        progress.completeLevel(.generate(number: 5, mode: .challenge))
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 75)
        XCTAssertTrue(progress.claimedMilestoneIDs.contains("first-five"))
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 0)
        XCTAssertEqual(progress.points, 325)
        let saved = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(ProgressData.self, from: saved)
        XCTAssertEqual(restored.claimMilestone(id: "first-five"), 0)
        XCTAssertEqual(restored.points, 325)
    }

    func testTimedMilestoneUsesActualCompletionsNotUnlockedFrontier() {
        var progress = ProgressData()
        progress.timedLevel = 100
        XCTAssertEqual(progress.claimMilestone(id: "timed-ten"), 0)
        for number in 1...10 { progress.completeLevel(.generate(number: number, mode: .timed)) }
        XCTAssertEqual(progress.completedLevelCount(in: .timed), 10)
        XCTAssertEqual(progress.completedLevelCount(in: .endless), 0)
        XCTAssertEqual(progress.claimMilestone(id: "timed-ten"), 200)
        XCTAssertEqual(progress.claimMilestone(id: "timed-ten"), 0)
    }

    func testSkinMilestoneRequiresFourDistinctOwnedSkins() {
        var progress = ProgressData()
        progress.points = 1000
        XCTAssertEqual(progress.claimMilestone(id: "skin-collector"), 0)
        for id in ["mint", "sunset", "tidal"] {
            XCTAssertTrue(progress.purchaseSkin(BallSkin.catalog.first { $0.id == id }!))
        }
        XCTAssertEqual(progress.ownedSkinIDs.count, 4)
        XCTAssertEqual(progress.claimMilestone(id: "skin-collector"), 150)
        XCTAssertEqual(progress.claimMilestone(id: "skin-collector"), 0)
        XCTAssertEqual(BallSkin.catalog.count, 12)
        XCTAssertEqual(Set(BallSkin.catalog.map(\.id)).count, 12)
    }
}
