import XCTest
@testable import PrismRoll

final class SaveMigrationTests: XCTestCase {
    func testOriginalProgressPayloadRetainsCurrencyPurchasesPreferencesAndLedgers() throws {
        let original = Data("""
        {
          "points":375,"endlessLevel":8,"challengeLevel":4,
          "ownedSkinIDs":["coral","mint"],"selectedSkinID":"mint",
          "hapticsEnabled":false,"soundEnabled":false,"completedLevels":2,
          "rewardedLevelKeys":["endless:1","challenge:1"],"bonusLevelKeys":["endless:1"]
        }
        """.utf8)
        var progress = try JSONDecoder().decode(ProgressData.self, from: original)
        XCTAssertEqual(progress.points, 375)
        XCTAssertEqual(progress.endlessLevel, 8)
        XCTAssertEqual(progress.challengeLevel, 4)
        XCTAssertEqual(progress.timedLevel, 1)
        XCTAssertEqual(progress.ownedSkinIDs, ["coral", "mint"])
        XCTAssertEqual(progress.selectedSkinID, "mint")
        XCTAssertFalse(progress.hapticsEnabled)
        XCTAssertFalse(progress.soundEnabled)
        XCTAssertFalse(progress.directionButtonsEnabled)
        XCTAssertFalse(progress.tutorialDismissed)
        XCTAssertEqual(progress.completedLevels, 2)
        XCTAssertEqual(progress.dailyStreak, 0)
        XCTAssertEqual(progress.dailyChallengeStreak, 0)
        XCTAssertTrue(progress.claimedMilestoneIDs.isEmpty)
        XCTAssertNil(progress.lastDailyRewardDate)
        let completed = MazeLevel.generate(number: 1, mode: .endless)
        XCTAssertTrue(progress.hasCompleted(completed))
        XCTAssertTrue(progress.hasClaimedAdBonus(level: completed))
        XCTAssertEqual(progress.completeLevel(completed), 0)
        XCTAssertEqual(progress.claimAdBonus(level: completed), 0)
        XCTAssertEqual(progress.points, 375)
        let savedAgain = try JSONEncoder().encode(progress)
        XCTAssertEqual(try JSONDecoder().decode(ProgressData.self, from: savedAgain), progress)
    }

    func testOriginalRunPayloadResumesWithoutNewFieldsOrRegeneration() throws {
        let original = Data("""
        {
          "level":{
            "number":7,"mode":"challenge","width":2,"height":2,
            "openCells":[{"row":0,"column":0},{"row":0,"column":1},{"row":1,"column":0},{"row":1,"column":1}],
            "start":{"row":0,"column":0},"solution":["right","down","left"],"moveLimit":5
          },
          "position":{"row":0,"column":1},
          "painted":[{"row":0,"column":0},{"row":0,"column":1}],
          "moves":1,"hintRoute":["down","left"]
        }
        """.utf8)
        var run = try JSONDecoder().decode(MazeRun.self, from: original)
        XCTAssertEqual(run.level.number, 7)
        XCTAssertEqual(run.level.width, 2, "Restoration must retain the original board")
        XCTAssertEqual(run.position, GridCell(row: 0, column: 1))
        XCTAssertEqual(run.painted.count, 2)
        XCTAssertEqual(run.moves, 1)
        XCTAssertEqual(run.extraMovesGranted, 0)
        XCTAssertEqual(run.remainingMoves, 4)
        XCTAssertEqual(run.hintDirection, .down)
        XCTAssertNil(run.level.timeLimit)
        XCTAssertTrue(run.level.coinCells.isEmpty)
        while let hint = run.hintDirection { run.move(hint) }
        XCTAssertTrue(run.isComplete)
        XCTAssertEqual(run.moves, 3)
    }

    func testMissingProgressFieldsUseDefaults() throws {
        let progress = try JSONDecoder().decode(ProgressData.self, from: Data("{}".utf8))
        XCTAssertEqual(progress, ProgressData())
    }

    func testControlAndTutorialPreferencesRoundTripWithoutChangingRewardHistory() throws {
        let previousSave = Data("""
        {
          "points":175,"endlessLevel":3,"ownedSkinIDs":["coral","mint"],
          "selectedSkinID":"mint","rewardedLevelKeys":["endless:1"],
          "directionButtonsEnabled":true,"tutorialDismissed":true
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(ProgressData.self, from: previousSave)
        var restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(decoded))
        XCTAssertTrue(restored.directionButtonsEnabled)
        XCTAssertTrue(restored.tutorialDismissed)
        XCTAssertEqual(restored.selectedSkinID, "mint")
        XCTAssertEqual(restored.ownedSkinIDs, ["coral", "mint"])
        XCTAssertEqual(restored.endlessLevel, 3)
        XCTAssertEqual(restored.completeLevel(.generate(number: 1, mode: .endless)), 0)
        XCTAssertEqual(restored.points, 175)
        XCTAssertEqual(restored, decoded)
    }

    func testPartiallyMigratedControlPreferencesKeepIndependentDefaults() throws {
        let controlsOnly = try JSONDecoder().decode(ProgressData.self, from: Data("{\"directionButtonsEnabled\":true}".utf8))
        XCTAssertTrue(controlsOnly.directionButtonsEnabled)
        XCTAssertFalse(controlsOnly.tutorialDismissed)
        let tutorialOnly = try JSONDecoder().decode(ProgressData.self, from: Data("{\"tutorialDismissed\":true}".utf8))
        XCTAssertFalse(tutorialOnly.directionButtonsEnabled)
        XCTAssertTrue(tutorialOnly.tutorialDismissed)
    }
}
