import XCTest
@testable import PrismRoll

final class ProgressDataTests: XCTestCase {
    func testAwardsAreIdempotentAcrossModesAndRelaunch() throws {
        var progress = ProgressData()
        let endless = MazeLevel.generate(number: 1, mode: .endless)
        let challenge = MazeLevel.generate(number: 1, mode: .challenge)
        XCTAssertEqual(progress.claimAdBonus(level: endless), 0)
        XCTAssertEqual(progress.completeLevel(endless), 50)
        XCTAssertEqual(progress.completeLevel(endless), 0)
        XCTAssertEqual(progress.completeLevel(challenge), 50)
        XCTAssertEqual(progress.points, 100)
        XCTAssertEqual(progress.endlessLevel, 2)
        XCTAssertEqual(progress.challengeLevel, 2)
        XCTAssertEqual(progress.completedLevels, 2)

        let data = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(ProgressData.self, from: data)
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.completeLevel(endless), 0)
        XCTAssertEqual(restored.claimAdBonus(level: endless), 50)
        XCTAssertEqual(restored.claimAdBonus(level: endless), 0)
        XCTAssertEqual(restored.points, 150)
        let rewardedSave = try JSONEncoder().encode(restored)
        restored = try JSONDecoder().decode(ProgressData.self, from: rewardedSave)
        XCTAssertEqual(restored.claimAdBonus(level: endless), 0)
    }

    func testPurchasesRequirePointsAndOnlyChargeOnce() {
        var progress = ProgressData()
        let mint = BallSkin.catalog.first { $0.id == "mint" }!
        XCTAssertFalse(progress.purchaseSkin(mint))
        XCTAssertEqual(progress.selectedSkinID, "coral")
        XCTAssertFalse(progress.selectSkin(id: "mint"))
        for number in 1...2 { progress.completeLevel(.generate(number: number, mode: .endless)) }
        XCTAssertTrue(progress.purchaseSkin(mint))
        XCTAssertEqual(progress.points, 0)
        XCTAssertTrue(progress.ownedSkinIDs.contains("mint"))
        XCTAssertEqual(progress.selectedSkinID, "mint")
        XCTAssertTrue(progress.purchaseSkin(mint))
        XCTAssertEqual(progress.ownedSkinIDs.filter { $0 == "mint" }.count, 1)
        XCTAssertTrue(progress.selectSkin(id: "coral"))
        XCTAssertEqual(progress.selectedSkinID, "coral")
    }

    func testForgedSkinCannotAlterCatalogPrice() {
        var progress = ProgressData()
        let forged = BallSkin(id: "mint", name: "Free mint", price: 0, hex: "000000", accentHex: "000000", pattern: "plain")
        XCTAssertFalse(progress.purchaseSkin(forged))
        XCTAssertEqual(progress.points, 0)
        let unknown = BallSkin(id: "unknown", name: "Unknown", price: 0, hex: "000000", accentHex: "000000", pattern: "plain")
        XCTAssertFalse(progress.purchaseSkin(unknown))
    }

    func testProgressNeverMovesBackwardOnReplay() {
        var progress = ProgressData()
        progress.completeLevel(.generate(number: 9, mode: .endless))
        progress.completeLevel(.generate(number: 1, mode: .endless))
        XCTAssertEqual(progress.endlessLevel, 10)
        XCTAssertEqual(progress.challengeLevel, 1)
        progress.completeLevel(.generate(number: Int.max, mode: .challenge))
        XCTAssertEqual(progress.challengeLevel, Int.max)
    }
}
