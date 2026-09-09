#if canImport(UIKit)
import Foundation
import XCTest
@testable import PrismRoll

@MainActor
final class GameDifficultyCompatibilityTests: XCTestCase {
    func testDifferingSoloGridsRefreshWhileKeepingExtensionsWalletAndUnlocks() throws {
        let suite = "PrismRoll.DifficultyCompatibility.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var progress = ProgressData()
        progress.points = 375
        progress.endlessLevel = 5
        progress.challengeLevel = 5
        progress.ownedSkinIDs = ["coral", "mint"]
        progress.selectedSkinID = "mint"
        progress.soundEnabled = false
        progress.hapticsEnabled = false
        var classic = MazeRun(level: legacyLevel(mode: .endless))
        classic.move(.right)
        var challenge = MazeRun(level: legacyLevel(mode: .challenge))
        challenge.move(.right)
        challenge.grantExtraMoves(count: 3)
        let snapshot = GameSnapshot(progress: progress, runs: ["endless": classic, "challenge": challenge],
                                    clocks: [:], mode: .endless, dailyRun: nil, dailyID: nil,
                                    dailyActive: false, themeID: "aurora")
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
        let canonicalClassic = MazeLevel.generate(number: 5, mode: .endless)
        var canonicalChallenge = MazeRun(level: .generate(number: 5, mode: .challenge))
        canonicalChallenge.grantExtraMoves(count: 3)
        let store = GameStore(defaults: defaults, uptime: { 0 })
        XCTAssertEqual(store.run, MazeRun(level: canonicalClassic))
        XCTAssertEqual(store.progress, progress)
        store.switchMode(.challenge)
        XCTAssertEqual(store.run, canonicalChallenge)
        XCTAssertEqual(store.run.extraMovesGranted, 3)
        store.openLevel(5)
        XCTAssertEqual(store.run, canonicalChallenge)
        store.switchMode(.endless)
        XCTAssertEqual(store.run, MazeRun(level: canonicalClassic))
        store.replay()
        XCTAssertEqual(store.run.level, canonicalClassic)
        XCTAssertEqual(store.run.moves, 0)
        XCTAssertEqual(store.run.hintDirection, canonicalClassic.solution.first)
        for direction in store.run.level.solution { store.move(direction) }
        XCTAssertTrue(store.advanceCompletedLevel(for: store.runID))
        XCTAssertEqual(store.run.level.number, 6)
        XCTAssertGreaterThan(store.run.level.width, classic.level.width)
        XCTAssertEqual(store.progress.points, 375 + 50 + canonicalClassic.coinCells.count * MazeLevel.coinValue)
        XCTAssertEqual(store.progress.selectedSkinID, "mint")
        let restored = GameStore(defaults: defaults, uptime: { 0 })
        XCTAssertEqual(restored.run, store.run)
        XCTAssertEqual(restored.progress, store.progress)
    }

    func testSameDayLegacyDailyBoardRemainsPlayableAndPaysOnlyOnce() throws {
        let suite = "PrismRoll.DailyDifficultyCompatibility.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date(timeIntervalSince1970: 1_788_695_000)
        let daily = DailyChallenge.generate(for: date)
        var oldDaily = MazeRun(level: legacyLevel(mode: .challenge, number: daily.level.number))
        oldDaily.move(.right)
        var progress = ProgressData()
        progress.soundEnabled = false
        progress.hapticsEnabled = false
        let snapshot = GameSnapshot(progress: progress, runs: [:], clocks: [:], mode: .endless,
                                    dailyRun: oldDaily, dailyID: daily.id, dailyActive: true, themeID: "aurora")
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
        let store = GameStore(defaults: defaults, now: { date }, uptime: { 0 })
        XCTAssertTrue(store.isDaily)
        XCTAssertEqual(store.run, oldDaily)
        store.move(.down)
        store.move(.left)
        XCTAssertTrue(store.run.isComplete)
        XCTAssertEqual(store.progress.points, 100)
        XCTAssertTrue(store.advanceCompletedLevel(for: store.runID))
        store.openDaily(replayCompleted: true)
        XCTAssertEqual(store.run.level, oldDaily.level)
        for direction in store.run.level.solution { store.move(direction) }
        XCTAssertTrue(store.run.isComplete)
        XCTAssertEqual(store.progress.points, 100)
        XCTAssertTrue(store.progress.hasCompletedDailyChallenge(daily))
    }

    func testDifferingTimeRushCourseRefreshesWithEarnedTimeAndWalletPreserved() throws {
        let suite = "PrismRoll.CourseDifficultyCompatibility.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let oldLevel = legacyLevel(mode: .timed)
        let oldCourse = TimeRushCourse(number: 5, levels: Array(repeating: oldLevel, count: 5), timeLimit: 60)
        let session = TimeRushSession(course: oldCourse, stageIndex: 2)
        var run = MazeRun(level: oldLevel)
        run.move(.right)
        let clock = TimedRunState(remainingSeconds: 13.25, hasStarted: true, rewardedExtensions: 2)
        var progress = ProgressData()
        progress.timedLevel = 5
        progress.points = 375
        progress.hapticsEnabled = false
        progress.soundEnabled = false
        let snapshot = GameSnapshot(progress: progress, runs: ["timed": run], clocks: ["timed": clock],
            mode: .timed, dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora", timeRushSession: session)
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")

        let canonicalCourse = TimeRushCourse.generate(number: 5)
        let extendedClock = TimedRunState(remainingSeconds: canonicalCourse.timeLimit + 60, rewardedExtensions: 2)
        let restored = GameStore(defaults: defaults, uptime: { 0 })
        XCTAssertEqual(restored.run, MazeRun(level: canonicalCourse.levels[0]))
        XCTAssertEqual(restored.timeRushSession, TimeRushSession(course: canonicalCourse))
        XCTAssertEqual(restored.clock, extendedClock)
        XCTAssertEqual(restored.progress, progress)
        for direction in restored.run.level.solution { restored.move(direction) }
        XCTAssertTrue(restored.advanceTimeRushMaze(after: restored.runID))
        XCTAssertEqual(restored.timeRushMazeNumber, 2)
        XCTAssertEqual(restored.run.level, canonicalCourse.levels[1])
        XCTAssertEqual(restored.clock?.remainingSeconds, extendedClock.remainingSeconds)
        XCTAssertEqual(restored.clock?.rewardedExtensions, 2)
        let progressAfterMaze = restored.progress
        XCTAssertEqual(progressAfterMaze.points, progress.points)
        XCTAssertEqual(progressAfterMaze.timedLevel, progress.timedLevel)
        let relaunched = GameStore(defaults: defaults, uptime: { 0 })
        XCTAssertEqual(relaunched.run, restored.run)
        XCTAssertEqual(relaunched.timeRushSession, restored.timeRushSession)
        XCTAssertEqual(relaunched.clock, restored.clock)
        restored.replay()
        XCTAssertEqual(restored.timeRushMazeNumber, 1)
        XCTAssertEqual(restored.run.level, canonicalCourse.levels[0])
        XCTAssertEqual(restored.clock?.remainingSeconds, canonicalCourse.timeLimit)
        XCTAssertEqual(restored.progress, progressAfterMaze)
    }

    private func legacyLevel(mode: GameMode, number: Int = 5) -> MazeLevel {
        MazeLevel(number: number, mode: mode, width: 2, height: 2,
                  openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1),
                              GridCell(row: 1, column: 0), GridCell(row: 1, column: 1)],
                  start: GridCell(row: 0, column: 0), solution: [.right, .down, .left],
                  moveLimit: mode == .challenge ? 5 : nil, timeLimit: mode == .timed ? 60 : nil)
    }
}
#endif
