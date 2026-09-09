import XCTest
@testable import PrismRoll

final class MilestoneChallengeTests: XCTestCase {
    func testClaimImmediatelyAdvancesFromFiveToTwentyFiveAndPreservesProgress() throws {
        var progress = try savedProgress(completions: 5)
        XCTAssertEqual(progress.currentMilestones.map(\.target), [5, 10, 10])
        XCTAssertEqual(progress.claimMilestone(id: "twenty-five"), 0)
        XCTAssertEqual(progress.claimMilestone(id: "missing"), 0)
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 75)
        let next = try XCTUnwrap(progress.currentMilestones.first)
        XCTAssertEqual(next.id, "twenty-five")
        XCTAssertEqual(next.target, 25)
        XCTAssertEqual(next.progress(in: progress), 5)
        XCTAssertFalse(next.isComplete(in: progress))
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 0)
        XCTAssertEqual(progress.claimMilestone(id: next.id), 0)
        XCTAssertEqual(progress.points, 75)
        let restored = try roundTrip(progress)
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.currentMilestones.first?.id, next.id)
    }

    func testOldClaimedAndUnclaimedLevelRewardsMigrateWithoutLossOrDuplicateAwards() throws {
        let cases: [([String], [String], Int)] = [
            ([], ["first-five", "twenty-five"], 275),
            (["first-five"], ["twenty-five"], 200),
            (["twenty-five"], ["first-five"], 75),
            (["first-five", "twenty-five"], [], 0)
        ]
        for (oldClaims, remainingIDs, reward) in cases {
            var progress = try savedProgress(completions: 25, claims: oldClaims, points: 123)
            for id in remainingIDs {
                XCTAssertEqual(progress.currentMilestones.first?.id, id)
                XCTAssertGreaterThan(progress.claimMilestone(id: id), 0)
                XCTAssertEqual(progress.claimMilestone(id: id), 0)
            }
            XCTAssertEqual(progress.currentMilestones.first?.target, 50)
            XCTAssertEqual(progress.points, 123 + reward)
            XCTAssertTrue(Set(oldClaims).isSubset(of: progress.claimedMilestoneIDs))
            XCTAssertEqual(try roundTrip(progress), progress)
        }
    }

    func testStaleClaimDoesNotCollectTheNextAlreadyCompletedTier() throws {
        var progress = try savedProgress(completions: 100)
        let first = try XCTUnwrap(progress.currentMilestones.first)
        XCTAssertEqual(progress.claimMilestone(id: first.id), 75)
        XCTAssertEqual(progress.claimMilestone(id: first.id), 0)
        XCTAssertEqual(progress.currentMilestones.first?.target, 25)
        XCTAssertEqual(progress.points, 75)
        XCTAssertEqual(progress.claimMilestone(id: "twenty-five"), 200)
        XCTAssertEqual(progress.currentMilestones.first?.target, 50)
        XCTAssertEqual(progress.claimMilestone(id: "levels:3"), 0, "Future tiers must not be claimed out of order")
    }

    func testGeneratedTracksKeepAdvancingThroughManyTiers() throws {
        let expected = [5, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000]
        for (tier, target) in expected.enumerated() {
            XCTAssertEqual(MilestoneChallenge.make(track: .levels, tier: tier).target, target)
        }
        for track in MilestoneChallenge.Track.allCases {
            var previous = 0
            var ids = Set<String>()
            for tier in 0..<54 {
                let milestone = MilestoneChallenge.make(track: track, tier: tier)
                let target = try XCTUnwrap(milestone.target)
                XCTAssertGreaterThan(target, previous)
                XCTAssertTrue(ids.insert(milestone.id).inserted)
                XCTAssertTrue((1...5_000).contains(milestone.reward))
                previous = target
            }
        }
    }

    func testTimedTrackUsesActualCompletionsAndAdvancesAfterAnOldClaim() throws {
        var progress = ProgressData()
        progress.timedLevel = 100
        XCTAssertEqual(progress.claimMilestone(id: "timed-ten"), 0)
        for number in 1...10 { progress.completeLevel(.generate(number: number, mode: .timed)) }
        XCTAssertEqual(progress.completedLevelCount(in: .timed), 10)
        XCTAssertEqual(progress.claimMilestone(id: "timed-ten"), 200)
        XCTAssertEqual(progress.claimMilestone(id: "timed-ten"), 0)
        let next = try XCTUnwrap(progress.currentMilestones.first(where: { $0.trackID == "timeRush" }))
        XCTAssertEqual(next.target, 25)
        XCTAssertEqual(next.progress(in: progress), 10)
        let migrated = try savedProgress(completions: 10, claims: ["timed-ten"], timedCompletions: 10)
        XCTAssertEqual(migrated.currentMilestones.first(where: { $0.trackID == "timeRush" })?.id, next.id)
    }

    func testCoinTrackCountsMazePickupsOnceAndIgnoresWalletBalanceAndSpending() throws {
        var progress = ProgressData()
        progress.points = 100_000
        XCTAssertEqual(progress.claimMilestone(id: "coins:0"), 0)
        for number in 1...4 {
            let level = MazeLevel(
                number: number, mode: .endless, width: 2, height: 2,
                openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1),
                            GridCell(row: 1, column: 1), GridCell(row: 1, column: 0)],
                start: GridCell(row: 0, column: 0), solution: [.right, .down, .left], moveLimit: nil,
                coinCells: [GridCell(row: 0, column: 1), GridCell(row: 1, column: 1), GridCell(row: 1, column: 0)]
            )
            var run = MazeRun(level: level)
            for direction in level.solution { run.move(direction) }
            XCTAssertEqual(progress.awardCollectedCoins(for: run), 15)
            XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
        }
        XCTAssertEqual(progress.collectedMazeCoinCount, 12)
        XCTAssertEqual(progress.claimMilestone(id: "coins:0"), 100)
        progress.points = 0
        let next = try XCTUnwrap(progress.currentMilestones.first(where: { $0.trackID == "coins" }))
        XCTAssertEqual(next.target, 25)
        XCTAssertEqual(next.progress(in: progress), 12)
        XCTAssertEqual(try roundTrip(progress), progress)
    }

    func testLegacyBallCollectorKeepsEarnedUnclaimedRewardAndNeverBecomesAStuckRow() throws {
        let skins = ["coral", "mint", "sunset", "tidal"]
        var earned = try savedProgress(ownedSkins: skins)
        XCTAssertEqual(earned.currentMilestones.count, 4)
        XCTAssertEqual(earned.currentMilestones.last?.id, "skin-collector")
        earned = try roundTrip(earned)
        XCTAssertEqual(earned.claimMilestone(id: "skin-collector"), 150)
        XCTAssertEqual(earned.claimMilestone(id: "skin-collector"), 0)
        XCTAssertEqual(earned.currentMilestones.count, 3)
        XCTAssertEqual(try roundTrip(earned).currentMilestones.count, 3)
        let claimed = try savedProgress(claims: ["skin-collector"], ownedSkins: skins)
        XCTAssertEqual(claimed.currentMilestones.count, 3)
        let unearned = try savedProgress(ownedSkins: ["coral", "mint"])
        XCTAssertEqual(unearned.currentMilestones.count, 3)
    }

    func testNewSavesDoNotGainRetiredBallMilestoneAfterBuyingSkins() throws {
        var progress = ProgressData()
        progress.points = 3_000
        for skin in BallSkin.catalog.prefix(4) { XCTAssertTrue(progress.purchaseSkin(skin)) }
        XCTAssertEqual(progress.currentMilestones.count, 3)
        var restored = try roundTrip(progress)
        XCTAssertEqual(restored.claimMilestone(id: "skin-collector"), 0)
        XCTAssertEqual(restored.currentMilestones.count, 3)
    }

    func testOldCoordinateCoinLedgerContributesToEvergreenCoinTrack() throws {
        let payload = Data("""
        {"collectedCoinKeys":["endless:1:0,1","endless:1:1,1","challenge:2:1,0"]}
        """.utf8)
        let progress = try JSONDecoder().decode(ProgressData.self, from: payload)
        XCTAssertEqual(progress.collectedMazeCoinCount, 3)
        XCTAssertEqual(progress.currentMilestones.first(where: { $0.trackID == "coins" })?.progress(in: progress), 3)
    }

    func testOverflowDoesNotCrashLoseAClaimOrCreateAnInfiniteReward() throws {
        var fullWallet = try savedProgress(completions: 5, points: Int.max)
        XCTAssertEqual(fullWallet.claimMilestone(id: "first-five"), 0)
        XCTAssertFalse(fullWallet.claimedMilestoneIDs.contains("first-five"))
        fullWallet.points -= 75
        XCTAssertEqual(fullWallet.claimMilestone(id: "first-five"), 75)
        XCTAssertEqual(fullWallet.points, Int.max)

        let claims = (0..<53).map { MilestoneChallenge.make(track: .levels, tier: $0).id }
        var highProgress = try savedProgress(completions: Int.max, claims: claims)
        let lastRepresentable = try XCTUnwrap(highProgress.currentMilestones.first)
        XCTAssertEqual(lastRepresentable.target, 5_000_000_000_000_000_000)
        XCTAssertEqual(highProgress.claimMilestone(id: lastRepresentable.id), 5_000)
        let next = try XCTUnwrap(highProgress.currentMilestones.first)
        XCTAssertNil(next.target)
        XCTAssertFalse(next.isComplete(in: highProgress))
        XCTAssertEqual(highProgress.claimMilestone(id: next.id), 0)
        XCTAssertEqual(highProgress.claimMilestone(id: lastRepresentable.id), 0)
        XCTAssertNil(MilestoneChallenge.make(track: .coins, tier: Int.max).target)
        highProgress.completeLevel(.generate(number: 1, mode: .endless))
        XCTAssertEqual(highProgress.completedLevels, Int.max)
        XCTAssertEqual(try roundTrip(highProgress), highProgress)
    }

    func testCoinLedgerDefaultsAndPersistsAlongsideMilestoneClaims() throws {
        var progress = try savedProgress(completions: 5)
        XCTAssertTrue(progress.receivedCoinTransactionIDs.isEmpty)
        progress.receivedCoinTransactionIDs.insert("purchase:12345")
        XCTAssertEqual(progress.claimMilestone(id: "first-five"), 75)
        XCTAssertEqual(try roundTrip(progress), progress)
    }

#if canImport(UIKit)
    @MainActor
    func testFailedMilestoneSaveKeepsTheRewardClaimableUntilDurableRetry() throws {
        let suite = "MilestoneSaveFailure.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let blocker = FileManager.default.temporaryDirectory.appending(path: suite)
        try Data("not a directory".utf8).write(to: blocker)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: blocker) }
        let original = try savedProgress(completions: 5, points: 250)
        defaults.set(try JSONEncoder().encode(original), forKey: "prism.progress")
        let url = blocker.appending(path: "progress.json")
        let store = GameStore(defaults: defaults, progressFileURL: url)

        store.claimMilestone("first-five")
        XCTAssertEqual(store.progress, original)
        XCTAssertEqual(store.progress.currentMilestones.first?.target, 5)
        XCTAssertEqual(store.notice, "Your reward could not be saved. Please try again.")
        XCTAssertNil(defaults.data(forKey: "prism.snapshot.v2"))

        try FileManager.default.removeItem(at: blocker)
        store.notice = nil
        store.claimMilestone("first-five")
        XCTAssertNil(store.notice)
        XCTAssertEqual(store.progress.points, 325)
        XCTAssertEqual(store.progress.currentMilestones.first?.target, 25)
        XCTAssertEqual(try JSONDecoder().decode(ProgressData.self, from: Data(contentsOf: url)), store.progress)
        let restored = GameStore(defaults: defaults, progressFileURL: url)
        XCTAssertEqual(restored.progress, store.progress)
        restored.claimMilestone("first-five")
        XCTAssertEqual(restored.progress.points, 325)
    }
#endif

    private func roundTrip(_ progress: ProgressData) throws -> ProgressData {
        try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
    }

    private func savedProgress(
        completions: Int = 0, claims: [String] = [], points: Int = 0,
        timedCompletions: Int = 0, ownedSkins: [String] = ["coral"]
    ) throws -> ProgressData {
        let payload: [String: Any] = [
            "completedLevels": completions, "claimedMilestoneIDs": claims, "points": points,
            "rewardedLevelKeys": (0..<timedCompletions).map { "timed:\($0 + 1)" },
            "ownedSkinIDs": ownedSkins
        ]
        return try JSONDecoder().decode(ProgressData.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
