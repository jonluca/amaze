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

    func testPurchasesRequirePointsAndOnlyChargeOnceAcrossRelaunch() throws {
        var progress = ProgressData()
        let mint = BallSkin.catalog.first { $0.id == "mint" }!
        XCTAssertFalse(progress.purchaseSkin(mint))
        XCTAssertEqual(progress.selectedSkinID, "coral")
        XCTAssertFalse(progress.selectSkin(id: "mint"))
        for number in 1...(mint.price / 50) {
            progress.completeLevel(.generate(number: number, mode: .endless))
        }
        XCTAssertTrue(progress.purchaseSkin(mint))
        XCTAssertEqual(progress.points, 0)
        XCTAssertTrue(progress.ownedSkinIDs.contains("mint"))
        XCTAssertEqual(progress.selectedSkinID, "mint")
        XCTAssertTrue(progress.purchaseSkin(mint))
        XCTAssertEqual(progress.ownedSkinIDs.filter { $0 == "mint" }.count, 1)
        XCTAssertTrue(progress.selectSkin(id: "coral"))
        XCTAssertEqual(progress.selectedSkinID, "coral")
        let saved = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(ProgressData.self, from: saved)
        XCTAssertTrue(restored.purchaseSkin(mint))
        XCTAssertEqual(restored.selectedSkinID, "mint")
        XCTAssertEqual(restored.points, 0)
        XCTAssertEqual(restored.ownedSkinIDs.filter { $0 == "mint" }.count, 1)
    }

    func testForgedSkinCannotAlterCatalogPrice() {
        for skin in BallSkin.catalog where skin.price > 0 {
            var progress = ProgressData()
            let forged = BallSkin(
                id: skin.id, name: "Discounted", price: 0, rarity: .common,
                hex: "000000", accentHex: "000000", pattern: "plain"
            )
            progress.points = skin.price - 1
            let before = progress
            XCTAssertFalse(progress.purchaseSkin(forged), skin.id)
            XCTAssertEqual(progress, before, skin.id)
            progress.points = skin.price + 7
            XCTAssertTrue(progress.purchaseSkin(forged), skin.id)
            XCTAssertEqual(progress.points, 7, skin.id)
            XCTAssertEqual(progress.selectedSkinID, skin.id)
        }
        var progress = ProgressData()
        let unknown = BallSkin(
            id: "unknown", name: "Unknown", price: 0, rarity: .mythic,
            hex: "000000", accentHex: "000000", pattern: "plain"
        )
        XCTAssertFalse(progress.purchaseSkin(unknown))
        XCTAssertEqual(progress, ProgressData())
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
