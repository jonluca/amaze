import XCTest
@testable import PrismRoll

final class BallCatalogTests: XCTestCase {
    func testCatalogHasUniqueSkinsAndOrderedRarityTiers() {
        let catalog = BallSkin.catalog
        let rarities = BallRarity.allCases
        XCTAssertEqual(catalog.count, 18)
        XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
        XCTAssertEqual(Set(catalog.map(\.name)).count, catalog.count)
        XCTAssertEqual(rarities, [.common, .uncommon, .rare, .epic, .legendary, .mythic])
        XCTAssertEqual(Set(catalog.map(\.rarity)), Set(rarities))

        let rarityIndices = catalog.map { rarities.firstIndex(of: $0.rarity)! }
        XCTAssertEqual(rarityIndices, rarityIndices.sorted())
        XCTAssertEqual(catalog.filter { $0.price == 0 }.map(\.id), ["coral"])
        for (previous, next) in zip(catalog, catalog.dropFirst()) {
            XCTAssertGreaterThan(next.price, previous.price, "\(previous.id) to \(next.id)")
        }
        XCTAssertEqual(catalog.first { $0.price > 0 }?.price, 500)
        XCTAssertEqual(catalog.last?.price, 150_000)
    }

    func testEveryPaidSkinRequiresItsFullPriceAndAcceptsAnExactBalance() throws {
        for skin in BallSkin.catalog where skin.price > 0 {
            var progress = ProgressData()
            progress.points = skin.price - 1
            let before = progress
            XCTAssertFalse(progress.purchaseSkin(skin), skin.id)
            XCTAssertEqual(progress, before, skin.id)

            progress.points += 1
            XCTAssertTrue(progress.purchaseSkin(skin), skin.id)
            XCTAssertEqual(progress.points, 0, skin.id)
            XCTAssertEqual(progress.ownedSkinIDs, ["coral", skin.id])
            XCTAssertEqual(progress.selectedSkinID, skin.id)

            let saved = try JSONEncoder().encode(progress)
            var restored = try JSONDecoder().decode(ProgressData.self, from: saved)
            XCTAssertTrue(restored.selectSkin(id: "coral"))
            XCTAssertTrue(restored.purchaseSkin(skin), skin.id)
            XCTAssertEqual(restored.points, 0, skin.id)
            XCTAssertEqual(restored.ownedSkinIDs, ["coral", skin.id])
            XCTAssertEqual(restored.selectedSkinID, skin.id)
        }
    }

    func testOriginalOwnersKeepAllSkinsAfterPriceChangesWithLowBalances() throws {
        let originalIDs = [
            "coral", "mint", "sunset", "tidal", "galaxy", "orbit",
            "ember", "frost", "jade", "nova", "aurora", "midnight"
        ]
        for balance in [0, 7] {
            // Legacy saves contain skin IDs, with no price or rarity metadata.
            let legacySave = try JSONSerialization.data(withJSONObject: [
                "points": balance,
                "ownedSkinIDs": originalIDs,
                "selectedSkinID": "midnight"
            ])
            var progress = try JSONDecoder().decode(ProgressData.self, from: legacySave)
            XCTAssertEqual(progress.selectedSkinID, "midnight")
            XCTAssertEqual(progress.ownedSkinIDs, originalIDs)

            for id in originalIDs {
                let skin = try XCTUnwrap(BallSkin.catalog.first { $0.id == id })
                XCTAssertTrue(progress.selectSkin(id: id), id)
                XCTAssertTrue(progress.purchaseSkin(skin), id)
                XCTAssertEqual(progress.selectedSkinID, id)
                XCTAssertEqual(progress.points, balance, id)
                XCTAssertEqual(progress.ownedSkinIDs, originalIDs)
            }
            let saved = try JSONEncoder().encode(progress)
            let restored = try JSONDecoder().decode(ProgressData.self, from: saved)
            XCTAssertEqual(restored, progress)
        }
    }
}
