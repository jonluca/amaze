#if canImport(UIKit)
import XCTest
@testable import PrismRoll

final class GameCenterReportLedgerTests: XCTestCase {
    func testFirstPlayerAdoptsProgressWithoutCompletionBannersAndNeverReportsZeros() {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 25, perfectCompleted: 1))
        var operations: [GameCenterReportOperation] = []
        while let operation = ledger.nextOperation(playerID: "first", allowBanners: true) {
            operations.append(operation)
            ledger.acknowledge(operation, playerID: "first")
        }
        XCTAssertFalse(operations.isEmpty)
        XCTAssertTrue(operations.contains(.leaderboard(id: GameCenterLeaderboard.classicCompleted.id, score: 25)))
        for operation in operations {
            switch operation {
            case let .achievement(_, percent, showBanner):
                XCTAssertGreaterThan(percent, 0)
                XCTAssertFalse(showBanner)
            case let .leaderboard(_, score): XCTAssertGreaterThan(score, 0)
            }
        }
        XCTAssertNil(ledger.nextOperation(playerID: "first", allowBanners: true))
    }

    func testFailureKeepsOperationQueuedAndRestoresAfterRelaunch() throws {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 1))
        let failedOperation = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: true))
        // Failure has no acknowledgement, so the exact operation remains durable.
        let restored = try JSONDecoder().decode(GameCenterReportLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored.nextOperation(playerID: "first", allowBanners: true), failedOperation)
    }

    func testOlderInflightAcknowledgementDoesNotEraseNewerProgress() throws {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 1))
        drain(&ledger, player: "first")
        ledger.observe(.init(classicCompleted: 2), playerID: "first", allowBanners: true)
        let operation = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: true))
        ledger.observe(.init(classicCompleted: 3), playerID: "first", allowBanners: true)
        ledger.acknowledge(operation, playerID: "first")
        let newer = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: true))
        guard case let .achievement(id, percent, _) = newer else { return XCTFail("Expected newer achievement progress") }
        XCTAssertEqual(id, GameCenterAchievement.classic25.id)
        XCTAssertEqual(percent, 12)
        XCTAssertEqual(ledger.accounts["first"]?.progress.classicCompleted, 3)
    }

    func testAccountSwitchKeepsReportsSeparateAndReturningPlayerSkipsOtherPlayersProgress() {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 25))
        let pendingFirst = ledger.nextOperation(playerID: "first", allowBanners: true)
        ledger.activate(playerID: "second", snapshot: .init(classicCompleted: 25))
        XCTAssertNil(ledger.nextOperation(playerID: "second", allowBanners: true))
        ledger.observe(.init(classicCompleted: 27), playerID: "second", allowBanners: true)
        XCTAssertEqual(ledger.accounts["second"]?.progress.classicCompleted, 2)
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 27))
        XCTAssertEqual(ledger.accounts["first"]?.progress.classicCompleted, 25)
        XCTAssertEqual(ledger.nextOperation(playerID: "first", allowBanners: true), pendingFirst)
        ledger.observe(.init(classicCompleted: 28), playerID: "first", allowBanners: true)
        XCTAssertEqual(ledger.accounts["first"]?.progress.classicCompleted, 26)
        XCTAssertEqual(ledger.accounts["second"]?.progress.classicCompleted, 2)
    }

    func testSameAccountReceivesOfflineProgressButDifferentAccountDoesNot() throws {
        var original = GameCenterReportLedger()
        original.activate(playerID: "first", snapshot: .init(classicCompleted: 5))
        let data = try JSONEncoder().encode(original)
        var samePlayer = try JSONDecoder().decode(GameCenterReportLedger.self, from: data)
        samePlayer.activate(playerID: "first", snapshot: .init(classicCompleted: 8))
        XCTAssertEqual(samePlayer.accounts["first"]?.progress.classicCompleted, 8)
        var newPlayer = try JSONDecoder().decode(GameCenterReportLedger.self, from: data)
        newPlayer.activate(playerID: "second", snapshot: .init(classicCompleted: 8))
        XCTAssertEqual(newPlayer.accounts["first"]?.progress.classicCompleted, 5)
        XCTAssertEqual(newPlayer.accounts["second"]?.progress.classicCompleted, 0)
    }

    func testFreshCompletionGetsBannerOnlyAfterBaselineAndRemoteCompletionSuppressesIt() {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .empty)
        ledger.observe(.init(classicCompleted: 1), playerID: "first", allowBanners: true)
        XCTAssertEqual(ledger.nextOperation(playerID: "first", allowBanners: true),
            .achievement(id: GameCenterAchievement.firstMaze.id, percent: 100, showBanner: true))
        ledger.mergeRemoteAchievements([GameCenterAchievement.firstMaze.id: 100], playerID: "first")
        XCTAssertFalse(ledger.accounts["first"]?.bannerEligibleAchievements.contains(GameCenterAchievement.firstMaze.id) ?? true)
        guard case let .achievement(id, _, showBanner) = ledger.nextOperation(playerID: "first", allowBanners: true) else {
            return XCTFail("Expected partial next achievement")
        }
        XCTAssertNotEqual(id, GameCenterAchievement.firstMaze.id)
        XCTAssertFalse(showBanner)
    }

    func testProgressEarnedBeforeRemoteBaselineDoesNotCreateBannerStorm() {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .empty)
        ledger.observe(.init(classicCompleted: 100, perfectCompleted: 25, mazeCoinsCollected: 100),
            playerID: "first", allowBanners: false)
        XCTAssertEqual(ledger.accounts["first"]?.bannerEligibleAchievements, [])
    }

    func testForeignObservationAndLateOldAccountAcknowledgementCannotAffectActiveAccount() throws {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 5))
        let operation = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: true))
        ledger.activate(playerID: "second", snapshot: .init(classicCompleted: 5))
        ledger.observe(.init(classicCompleted: 99), playerID: "first", allowBanners: true)
        ledger.acknowledge(operation, playerID: "first")
        XCTAssertEqual(ledger.accounts["second"]?.progress.classicCompleted, 0)
        XCTAssertEqual(ledger.accounts["second"]?.reportedAchievements, [:])
        XCTAssertEqual(ledger.lastObservedSnapshot?.classicCompleted, 5)
    }

    func testPersistenceRestoresQueuedProgressAndAcknowledgements() throws {
        let suite = "GameCenterReportLedgerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = GameCenterReportPersistence(defaults: defaults)
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 7))
        let operation = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: true))
        ledger.acknowledge(operation, playerID: "first")
        persistence.save(ledger)
        XCTAssertEqual(persistence.load(), ledger)
    }

    func testFailedResourceDoesNotBlockOthersOrLoopWithinBatch() throws {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 5))
        let failed = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: true))
        let excluded = Set([failed.resourceKey])
        var successfulOperations = 0
        while let operation = ledger.nextOperation(playerID: "first", allowBanners: true,
            excludingResources: excluded) {
            XCTAssertNotEqual(operation.resourceKey, failed.resourceKey)
            ledger.acknowledge(operation, playerID: "first")
            successfulOperations += 1
            XCTAssertLessThan(successfulOperations, 20)
        }
        XCTAssertGreaterThan(successfulOperations, 0)
        XCTAssertEqual(ledger.accounts["first"]?.reportedScores[GameCenterLeaderboard.classicCompleted.id], 5)
        XCTAssertEqual(ledger.nextOperation(playerID: "first", allowBanners: true), failed)
    }

    func testMissingAchievementBaselineStillAllowsLeaderboardReports() throws {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(classicCompleted: 5))
        let score = try XCTUnwrap(ledger.nextOperation(playerID: "first", allowBanners: false,
            includeAchievements: false))
        XCTAssertEqual(score, .leaderboard(id: GameCenterLeaderboard.classicCompleted.id, score: 5))
        ledger.acknowledge(score, playerID: "first")
        XCTAssertNil(ledger.nextOperation(playerID: "first", allowBanners: false, includeAchievements: false))
        XCTAssertNotNil(ledger.nextOperation(playerID: "first", allowBanners: false))
    }

    func testRegressedLocalCountDoesNotEarnDuplicateProgressWhenRestored() {
        var ledger = GameCenterReportLedger()
        ledger.activate(playerID: "first", snapshot: .init(perfectCompleted: 10))
        ledger.observe(.init(perfectCompleted: 5), playerID: "first", allowBanners: true)
        // Reauthentication/relaunch at the regressed count also keeps its high-water mark.
        ledger.activate(playerID: "first", snapshot: .init(perfectCompleted: 5))
        ledger.observe(.init(perfectCompleted: 10), playerID: "first", allowBanners: true)
        XCTAssertEqual(ledger.accounts["first"]?.progress.perfectCompleted, 10)
        ledger.observe(.init(perfectCompleted: 11), playerID: "first", allowBanners: true)
        XCTAssertEqual(ledger.accounts["first"]?.progress.perfectCompleted, 11)
    }

    private func drain(_ ledger: inout GameCenterReportLedger, player: String) {
        while let operation = ledger.nextOperation(playerID: player, allowBanners: false) {
            ledger.acknowledge(operation, playerID: player)
        }
    }
}
#endif
