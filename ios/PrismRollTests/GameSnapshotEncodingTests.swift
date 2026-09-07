#if canImport(UIKit)
import XCTest
@testable import PrismRoll

final class GameSnapshotEncodingTests: XCTestCase {
    func testCachedEncodingPreservesEveryMoveAndExistingJSONSchema() throws {
        var snapshot = makeSnapshot()
        for number in 1...1_000 { snapshot.progress.completeLevel(.generate(number: number, mode: .endless)) }
        let encoder = GameSnapshotEncoder()
        let oldData = try JSONEncoder().encode(snapshot)
        snapshot = try JSONDecoder().decode(GameSnapshot.self, from: oldData)
        var run = try XCTUnwrap(snapshot.runs["endless"])
        let forward = try XCTUnwrap(run.hintDirection)
        let backward: MoveDirection
        switch forward {
        case .up: backward = .down
        case .down: backward = .up
        case .left: backward = .right
        case .right: backward = .left
        }
        for index in 0..<300 {
            XCTAssertFalse(run.move(index.isMultiple(of: 2) ? forward : backward).isEmpty)
            snapshot.runs["endless"] = run
            snapshot.clocks["timed"]?.remainingSeconds -= 0.01
            let data = try encoder.encode(snapshot)
            let restored = try JSONDecoder().decode(GameSnapshot.self, from: data)
            assertEqual(restored, snapshot)
            XCTAssertEqual(restored.runs["endless"]?.moves, index + 1)
        }
    }

    func testEveryProgressMutationInvalidatesTheCachedLedger() throws {
        var snapshot = makeSnapshot()
        let encoder = GameSnapshotEncoder()
        let level = MazeLevel.generate(number: 5, mode: .endless)
        var coinRun = MazeRun(level: level)
        for direction in level.solution { coinRun.move(direction) }
        let date = Date(timeIntervalSince1970: 1_788_696_000)
        let daily = DailyChallenge.generate(for: date)
        let mutations: [(inout ProgressData) -> Void] = [
            { $0.points = 2_000 },
            { $0.completeLevel(level) },
            { $0.claimAdBonus(level: level) },
            { $0.awardCollectedCoins(for: coinRun) },
            { $0.claimDailyReward(at: date) },
            { $0.completeDailyChallenge(daily, at: date) },
            { for number in 1...4 { $0.completeLevel(.generate(number: number, mode: .endless)) } },
            { $0.claimMilestone(id: "first-five") },
            { $0.purchaseSkin(BallSkin.catalog[1]) },
            { $0.selectSkin(id: "coral") },
            { $0.challengeLevel = 40 },
            { $0.timedLevel = 70 },
            { $0.hapticsEnabled = false },
            { $0.soundEnabled = false },
            { $0.directionButtonsEnabled = true },
            { $0.tutorialDismissed = true }
        ]
        for mutate in mutations {
            _ = try encoder.encode(snapshot)
            let previous = snapshot.progress
            mutate(&snapshot.progress)
            XCTAssertNotEqual(snapshot.progress, previous, "Each case must exercise an actual progress change")
            let restored = try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot))
            assertEqual(restored, snapshot)
        }
    }

    func testEscapedMetadataAndSpecialSessionChangesRemainValidJSON() throws {
        var snapshot = makeSnapshot()
        let encoder = GameSnapshotEncoder()
        _ = try encoder.encode(snapshot)
        snapshot.themeID = "Quoted \"theme\" \\ path\n\u{0000} 🌈"
        snapshot.dailyID = "Custom \"day\"\n"
        snapshot.dailyActive = true
        snapshot.mode = .challenge
        snapshot.dailyRun = MazeRun(level: .generate(number: 123, mode: .challenge))
        assertEqual(try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot)), snapshot)
        snapshot.dailyID = nil
        snapshot.dailyRun = nil
        snapshot.dailyActive = false
        snapshot.clocks.removeAll()
        assertEqual(try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot)), snapshot)
    }

    func testTimeRushCourseStageAndSharedClockSurviveEveryTransition() throws {
        var snapshot = makeSnapshot()
        snapshot.progress.points = 250
        let encoder = GameSnapshotEncoder()
        _ = try encoder.encode(snapshot)
        let course = TimeRushCourse.generate(number: 27)
        snapshot.mode = .timed
        snapshot.timeRushSession = TimeRushSession(course: course)
        for stage in course.levels.indices {
            snapshot.timeRushSession?.stageIndex = stage
            var run = MazeRun(level: course.levels[stage])
            run.move(try XCTUnwrap(run.hintDirection))
            snapshot.runs["timed"] = run
            snapshot.clocks["timed"] = TimedRunState(remainingSeconds: 60 - Double(stage) * 8.5, hasStarted: true)
            let restored = try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot))
            assertEqual(restored, snapshot)
            XCTAssertEqual(restored.timeRushSession?.course, course)
            XCTAssertEqual(restored.timeRushSession?.stageIndex, stage)
            XCTAssertEqual(restored.runs["timed"]?.level, restored.timeRushSession?.currentLevel)
        }
        snapshot.mode = .endless
        assertEqual(try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot)), snapshot)
        snapshot.timeRushSession = nil
        assertEqual(try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot)), snapshot)
    }

    func testFailedEncodingCannotLeakCachedProgressIntoTheNextSave() throws {
        var snapshot = makeSnapshot()
        let encoder = GameSnapshotEncoder()
        _ = try encoder.encode(snapshot)
        let originalProgress = snapshot.progress
        snapshot.progress.points += 50
        snapshot.clocks["timed"]?.remainingSeconds = .infinity
        XCTAssertThrowsError(try encoder.encode(snapshot))
        snapshot.progress = originalProgress
        snapshot.clocks["timed"]?.remainingSeconds = 10
        assertEqual(try JSONDecoder().decode(GameSnapshot.self, from: encoder.encode(snapshot)), snapshot)
    }

    private func makeSnapshot() -> GameSnapshot {
        GameSnapshot(progress: ProgressData(), runs: [
            "endless": MazeRun(level: .generate(number: 100, mode: .endless)),
            "timed": MazeRun(level: .generate(number: 80, mode: .timed))
        ], clocks: ["timed": TimedRunState(remainingSeconds: 45, hasStarted: true)], mode: .endless,
        dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora")
    }

    private func assertEqual(_ actual: GameSnapshot, _ expected: GameSnapshot, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.progress, expected.progress, file: file, line: line)
        XCTAssertEqual(actual.runs, expected.runs, file: file, line: line)
        XCTAssertEqual(actual.clocks, expected.clocks, file: file, line: line)
        XCTAssertEqual(actual.mode, expected.mode, file: file, line: line)
        XCTAssertEqual(actual.dailyRun, expected.dailyRun, file: file, line: line)
        XCTAssertEqual(actual.dailyID, expected.dailyID, file: file, line: line)
        XCTAssertEqual(actual.dailyActive, expected.dailyActive, file: file, line: line)
        XCTAssertEqual(actual.themeID, expected.themeID, file: file, line: line)
        XCTAssertEqual(actual.timeRushSession, expected.timeRushSession, file: file, line: line)
    }
}
#endif
