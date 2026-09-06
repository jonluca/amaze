#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameStoreTests: XCTestCase {
    func testCompletionRewardAndBonusAreOnceOnlyAcrossReplayAndRelaunch() throws {
        try withStore { store, defaults in
            let level = store.run.level
            store.claimAdBonus(for: level)
            XCTAssertEqual(store.progress.points, 0, "Uncompleted levels cannot receive an ad bonus")
            completeCurrentLevel(store)
            XCTAssertEqual(store.progress.points, 50)
            XCTAssertEqual(store.progress.completedLevels, 1)
            XCTAssertEqual(store.currentUnlockedLevel, 2)
            XCTAssertEqual(store.earnedPoints, 50)
            XCTAssertTrue(store.canClaimAdBonus)

            store.claimAdBonus(for: level)
            store.claimAdBonus(for: level)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertTrue(store.bonusClaimed)
            XCTAssertFalse(store.canClaimAdBonus)

            store.replay()
            completeCurrentLevel(store)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertEqual(store.progress.completedLevels, 1)
            XCTAssertEqual(store.earnedPoints, 0)
            XCTAssertFalse(store.canClaimAdBonus)

            let restored = GameStore(defaults: defaults)
            XCTAssertTrue(restored.run.isComplete)
            XCTAssertEqual(restored.progress.points, 100)
            XCTAssertFalse(restored.canClaimAdBonus)
            restored.claimAdBonus(for: level)
            XCTAssertEqual(restored.progress.points, 100)
        }
    }

    func testUnclaimedBonusSurvivesRelaunchWithoutReawardingBasePoints() throws {
        try withStore { store, defaults in
            completeCurrentLevel(store)
            let restored = GameStore(defaults: defaults)
            XCTAssertTrue(restored.run.isComplete)
            XCTAssertEqual(restored.progress.points, 50)
            XCTAssertEqual(restored.earnedPoints, 0, "Restoring a completion does not earn another base reward")
            XCTAssertTrue(restored.canClaimAdBonus)
            XCTAssertFalse(restored.bonusClaimed)

            restored.claimAdBonus(for: restored.run.level)
            XCTAssertEqual(restored.progress.points, 100)
            XCTAssertFalse(GameStore(defaults: defaults).canClaimAdBonus)
        }
    }

    func testUnclaimedBonusSurvivesModeSwitchAndCompletedLevelReplay() throws {
        try withStore { store, _ in
            completeCurrentLevel(store)
            store.switchMode(.challenge)
            XCTAssertFalse(store.canClaimAdBonus)
            store.switchMode(.endless)
            XCTAssertTrue(store.run.isComplete)
            XCTAssertTrue(store.canClaimAdBonus)
            XCTAssertEqual(store.earnedPoints, 0)

            store.replay()
            XCTAssertFalse(store.canClaimAdBonus)
            completeCurrentLevel(store)
            XCTAssertTrue(store.canClaimAdBonus)
            XCTAssertEqual(store.progress.points, 50)
            XCTAssertEqual(store.progress.completedLevels, 1)
            store.claimAdBonus(for: store.run.level)
            XCTAssertEqual(store.progress.points, 100)
        }
    }

    func testDelayedRewardCreditsOriginatingLevelInsteadOfCurrentCompletion() throws {
        try withStore { store, defaults in
            completeCurrentLevel(store)
            let rewardedLevel = store.run.level
            // This models the closure captured when a rewarded video begins.
            let didEarnReward = { store.claimAdBonus(for: rewardedLevel) }

            store.switchMode(.challenge)
            completeCurrentLevel(store)
            let currentLevel = store.run.level
            XCTAssertEqual(store.progress.points, 100)
            didEarnReward()
            XCTAssertEqual(store.progress.points, 150)
            XCTAssertTrue(store.progress.hasClaimedAdBonus(level: rewardedLevel))
            XCTAssertFalse(store.progress.hasClaimedAdBonus(level: currentLevel))
            XCTAssertFalse(store.bonusClaimed)
            XCTAssertTrue(store.canClaimAdBonus, "Rewarding another completion must leave this offer intact")

            didEarnReward()
            XCTAssertEqual(store.progress.points, 150)
            store.claimAdBonus(for: currentLevel)
            XCTAssertEqual(store.progress.points, 200)
            let restored = GameStore(defaults: defaults)
            XCTAssertEqual(restored.progress.points, 200)
            XCTAssertFalse(restored.canClaimAdBonus)
            restored.switchMode(.endless)
            XCTAssertFalse(restored.canClaimAdBonus)
        }
    }

    func testEarnedRewardCanFinishAfterAdvancingToAnIncompleteLevel() throws {
        try withStore { store, defaults in
            completeCurrentLevel(store)
            let rewardedLevel = store.run.level
            store.nextLevel()
            let nextRun = store.run
            XCTAssertFalse(store.run.isComplete)
            store.claimAdBonus(for: rewardedLevel)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertEqual(store.run, nextRun, "A delayed ad callback must not change gameplay state")
            XCTAssertFalse(store.canClaimAdBonus)
            XCTAssertFalse(store.bonusClaimed)
            XCTAssertEqual(GameStore(defaults: defaults).progress.points, 100)
        }
    }

    func testPartialRunsAndActiveModePersistIndependently() throws {
        try withStore { store, defaults in
            store.move(try XCTUnwrap(store.run.hintDirection))
            let endlessRun = store.run
            store.switchMode(.challenge)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let challengeRun = store.run

            let restored = GameStore(defaults: defaults)
            XCTAssertEqual(restored.mode, .challenge)
            XCTAssertEqual(restored.run, challengeRun)
            XCTAssertEqual(restored.progress.points, 0)
            restored.switchMode(.endless)
            XCTAssertEqual(restored.run, endlessRun)
            restored.switchMode(.challenge)
            XCTAssertEqual(restored.run, challengeRun)
        }
    }

    private func completeCurrentLevel(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) {
        let route = store.run.level.solution
        for direction in route { store.move(direction) }
        XCTAssertTrue(store.run.isComplete, file: file, line: line)
    }

    private func withStore(_ body: (GameStore, UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.GameStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults)
        store.setHaptics(false)
        store.setSound(false)
        try body(store, defaults)
    }
}
#endif
