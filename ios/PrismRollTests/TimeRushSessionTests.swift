#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class TimeRushSessionTests: XCTestCase {
    func testFocusedPlayFinishesFiveMazesButPreviouslyAllowedSlowCadenceExpires() throws {
        let firstRoundMoves = try assertTimedCadence(number: 1, secondsPerSwipe: 0.35, completes: true)
        _ = try assertTimedCadence(number: 20, secondsPerSwipe: 0.25, completes: true)
        let slowMoves = try assertTimedCadence(number: 1, secondsPerSwipe: 0.8, completes: false)

        XCTAssertLessThan(slowMoves, firstRoundMoves)
        // The first swipe starts the clock; each later board takes one second
        // to read. This same executable route fit comfortably in the old 2:00.
        let slowFullCourseSeconds = Double(firstRoundMoves - 1) * 0.8 + 4
        XCTAssertLessThan(slowFullCourseSeconds, 120)
    }

    func testCourseUsesOneClockAcrossMazesAndExcludesSceneTransitionTime() throws {
        try withDefaults { defaults in
            var uptime = 10.0
            let store = makeStore(defaults, uptime: { uptime })
            store.switchMode(.timed)
            store.setPresentationReady(true, for: store.runID)
            let budget = try XCTUnwrap(store.clock?.remainingSeconds)
            XCTAssertGreaterThanOrEqual(store.timeRushMazeCount, 5)
            XCTAssertEqual(store.timeRushMazeNumber, 1)
            XCTAssertEqual(store.timeRushMazesCompleted, 0)
            uptime += 100
            store.tick()
            XCTAssertEqual(store.clock?.remainingSeconds, budget)

            store.move(try XCTUnwrap(store.run.hintDirection))
            uptime += 7.25
            store.tick()
            try completeMaze(store)
            let completedID = store.runID
            let remaining = try XCTUnwrap(store.clock?.remainingSeconds)
            XCTAssertEqual(remaining, budget - 7.25, accuracy: 0.001)
            XCTAssertTrue(store.isAwaitingTimeRushMaze)
            XCTAssertFalse(store.hasEnded)
            XCTAssertFalse(store.clockRunning)
            XCTAssertFalse(store.acceptsGameplayInput)
            XCTAssertEqual(store.timeRushMazesCompleted, 1)

            uptime += 30
            store.tick()
            XCTAssertEqual(store.clock?.remainingSeconds, remaining)
            XCTAssertTrue(store.advanceTimeRushMaze(after: completedID))
            XCTAssertEqual(store.timeRushMazeNumber, 2)
            XCTAssertEqual(store.timeRushMazesCompleted, 1)
            XCTAssertFalse(store.clockRunning, "The next scene must be ready before the shared clock resumes")
            uptime += 30
            store.tick()
            XCTAssertEqual(store.clock?.remainingSeconds, remaining)

            store.setPresentationReady(true, for: store.runID)
            XCTAssertTrue(store.clockRunning, "Only the first maze waits for its first swipe")
            uptime += 0.75
            store.tick()
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), budget - 8, accuracy: 0.001)
        }
    }

    func testOnlyMatchingSettledMazeCanAdvanceAndPreviousInputCannotReachNextMaze() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults)
            store.switchMode(.timed)
            XCTAssertFalse(store.advanceTimeRushMaze(after: store.runID))
            let previousInputID = store.inputID
            try completeMaze(store)
            let completedID = store.runID
            let completed = store.run
            store.move(.up, for: previousInputID)
            XCTAssertEqual(store.run, completed)
            XCTAssertNil(store.rewardRequest(.hint))
            XCTAssertNil(store.rewardRequest(.extraTime))
            XCTAssertFalse(store.advanceCompletedLevel(for: completedID), "A single maze must not skip the rest of its course")
            XCTAssertFalse(store.advanceTimeRushMaze(after: UUID()))
            XCTAssertTrue(store.advanceTimeRushMaze(after: completedID))
            let next = store.run
            XCTAssertNotEqual(store.runID, completedID)
            XCTAssertNotEqual(store.inputID, previousInputID)
            XCTAssertFalse(store.advanceTimeRushMaze(after: completedID))
            store.move(try XCTUnwrap(next.hintDirection), for: previousInputID)
            XCTAssertEqual(store.run, next)
            XCTAssertEqual(store.timeRushMazeNumber, 2)
        }
    }

    func testPartialAndFailedCoursesDoNotAwardCompletionOrUnlockNextCourse() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults, uptime: { uptime })
            store.switchMode(.timed)
            let balance = store.progress.points
            let initialCompletions = store.progress.completedLevels
            let firstMaze = store.run.level
            try completeMaze(store)
            XCTAssertEqual(store.earnedPoints, 0)
            XCTAssertEqual(store.progress.points, balance)
            XCTAssertEqual(store.progress.completedLevels, initialCompletions)
            XCTAssertEqual(store.progress.timedLevel, 1)
            XCTAssertFalse(store.progress.hasCompleted(firstMaze))
            XCTAssertFalse(store.canClaimAdBonus)
            store.claimAdBonus(for: firstMaze)
            XCTAssertEqual(store.progress.points, balance)

            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            uptime += 1_000
            store.tick()
            XCTAssertTrue(store.isFailed)
            XCTAssertTrue(store.hasEnded)
            XCTAssertEqual(store.timeRushMazesCompleted, 1)
            XCTAssertFalse(store.advanceTimeRushMaze(after: store.runID))
            XCTAssertFalse(store.advanceCompletedLevel(for: store.runID))
            XCTAssertEqual(store.progress.points, balance)
            XCTAssertEqual(store.progress.completedLevels, initialCompletions)
            XCTAssertEqual(store.progress.timedLevel, 1)
        }
    }

    func testOnlyFinalMazeAwardsOneCoursePrizeAndBonusSurvivesAdvanceAndReplay() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults)
            store.switchMode(.timed)
            try completeCourse(store)
            let completedID = store.runID
            let completedLevel = store.run.level
            XCTAssertTrue(store.hasEnded)
            XCTAssertFalse(store.isFailed)
            XCTAssertFalse(store.isAwaitingTimeRushMaze)
            XCTAssertEqual(store.timeRushMazesCompleted, store.timeRushMazeCount)
            XCTAssertEqual(store.earnedPoints, 50)
            XCTAssertEqual(store.progress.points, 50)
            XCTAssertEqual(store.progress.completedLevels, 1)
            XCTAssertEqual(store.progress.timedLevel, 2)
            XCTAssertTrue(store.canClaimAdBonus)
            XCTAssertFalse(store.advanceTimeRushMaze(after: completedID))
            XCTAssertTrue(store.advanceCompletedLevel(for: completedID))
            XCTAssertFalse(store.advanceCompletedLevel(for: completedID))
            XCTAssertEqual(store.run.level.number, 2)
            XCTAssertEqual(store.timeRushMazeNumber, 1)
            XCTAssertFalse(try XCTUnwrap(store.clock).hasStarted)
            let nextRun = store.run
            store.claimAdBonus(for: completedLevel)
            store.claimAdBonus(for: completedLevel)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertEqual(store.run, nextRun)

            store.openLevel(1)
            try completeCourse(store)
            XCTAssertEqual(store.earnedPoints, 0)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertEqual(store.progress.completedLevels, 1)
            XCTAssertFalse(store.canClaimAdBonus)
            let restored = makeStore(defaults)
            XCTAssertEqual(restored.progress.points, 100)
            XCTAssertEqual(restored.progress.completedLevels, 1)
            XCTAssertTrue(restored.hasEnded)
            XCTAssertEqual(restored.timeRushMazesCompleted, restored.timeRushMazeCount)
            restored.claimAdBonus(for: completedLevel)
            XCTAssertEqual(restored.progress.points, 100)
        }
    }

    func testReplayRestartsEntireCourseWithFreshClockAndRejectsOldCallbacks() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults)
            store.switchMode(.timed)
            let firstRun = store.run
            let budget = store.clock?.remainingSeconds
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            let stageID = store.runID
            let reward = try XCTUnwrap(store.rewardRequest(.extraTime))
            store.applyReward(reward)
            store.replay()
            XCTAssertEqual(store.run, firstRun)
            XCTAssertEqual(store.timeRushMazeNumber, 1)
            XCTAssertEqual(store.timeRushMazesCompleted, 0)
            XCTAssertEqual(store.clock?.remainingSeconds, budget)
            XCTAssertEqual(store.clock?.rewardedExtensions, 0)
            XCTAssertFalse(try XCTUnwrap(store.clock).hasStarted)
            XCTAssertFalse(store.hasEnded)
            XCTAssertFalse(store.advanceTimeRushMaze(after: stageID))
            store.applyReward(reward)
            XCTAssertEqual(store.clock?.remainingSeconds, budget)
        }
    }

    func testEarnedTimeRevivesSecondMazeOnceAndCarriesIntoThirdMaze() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults, uptime: { uptime })
            store.switchMode(.timed)
            let previousReward = try XCTUnwrap(store.rewardRequest(.extraTime))
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            let beforeStaleReward = store.clock
            store.applyReward(previousReward)
            XCTAssertEqual(store.clock, beforeStaleReward)
            uptime += 1_000
            store.tick()
            XCTAssertTrue(store.isFailed)
            let expiredRun = store.run
            let reward = try XCTUnwrap(store.rewardRequest(.extraTime))
            store.beginReward()
            uptime += 100
            store.applyReward(reward)
            store.applyReward(reward)
            XCTAssertEqual(store.clock?.remainingSeconds, 30)
            XCTAssertEqual(store.clock?.rewardedExtensions, 1)
            XCTAssertEqual(store.run, expiredRun)
            XCTAssertEqual(store.timeRushMazeNumber, 2)
            XCTAssertFalse(store.isFailed)
            XCTAssertFalse(store.clockRunning)
            store.finishReward()
            uptime += 2.5
            store.tick()
            XCTAssertEqual(store.clock?.remainingSeconds, 27.5)
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            XCTAssertEqual(store.timeRushMazeNumber, 3)
            XCTAssertEqual(store.clock?.remainingSeconds, 27.5)
            XCTAssertEqual(store.clock?.rewardedExtensions, 1)
            XCTAssertTrue(store.clockRunning)
            store.applyReward(reward)
            XCTAssertEqual(store.clock?.remainingSeconds, 27.5)
        }
    }

    func testOpeningDifferentUnlockedCourseStartsAtFirstMazeWithItsOwnBudget() throws {
        try withDefaults { defaults in
            var progress = ProgressData()
            progress.timedLevel = 4
            defaults.set(try JSONEncoder().encode(progress), forKey: "prism.progress")
            let store = makeStore(defaults)
            store.switchMode(.timed)
            XCTAssertEqual(store.run.level.number, 4)
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            store.applyReward(try XCTUnwrap(store.rewardRequest(.extraTime)))
            store.openLevel(2)
            XCTAssertEqual(store.run.level.number, 2)
            XCTAssertEqual(store.timeRushMazeNumber, 1)
            XCTAssertEqual(store.timeRushMazesCompleted, 0)
            XCTAssertEqual(store.run.moves, 0)
            XCTAssertFalse(try XCTUnwrap(store.clock).hasStarted)
            XCTAssertEqual(store.clock?.rewardedExtensions, 0)
            XCTAssertEqual(store.clock?.remainingSeconds, store.timeRushSession?.course.timeLimit)
            XCTAssertEqual(store.progress.timedLevel, 4)
        }
    }

    func testJourneyAndRelaunchResumeExactStagePaintAndFractionalClock() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults, uptime: { uptime })
            store.switchMode(.timed)
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            store.move(try XCTUnwrap(store.run.hintDirection))
            store.applyReward(try XCTUnwrap(store.rewardRequest(.extraTime)))
            uptime += 2.25
            store.setActivity(visible: false)
            let savedRun = store.run
            let savedClock = store.clock
            let savedSession = store.timeRushSession
            uptime += 1_000
            store.openLevel(1)
            XCTAssertEqual(store.run, savedRun)
            XCTAssertEqual(store.clock, savedClock)
            XCTAssertEqual(store.timeRushSession, savedSession)
            let restored = makeStore(defaults, uptime: { uptime })
            XCTAssertTrue(restored.isTimeRush)
            XCTAssertEqual(restored.run, savedRun)
            XCTAssertEqual(restored.clock, savedClock)
            XCTAssertEqual(restored.timeRushSession, savedSession)
            XCTAssertEqual(restored.timeRushMazeNumber, 2)
            XCTAssertEqual(restored.clock?.rewardedExtensions, 1)
        }
    }

    func testExpiredSecondMazeStaysExpiredWhenOpenedFromJourneyOrRelaunched() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults, uptime: { uptime })
            store.switchMode(.timed)
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            uptime += 1_000
            store.tick()
            let expiredRun = store.run
            XCTAssertTrue(store.isFailed)
            store.openLevel(1)
            XCTAssertEqual(store.run, expiredRun)
            XCTAssertEqual(store.timeRushMazeNumber, 2)
            XCTAssertEqual(store.clock?.remainingSeconds, 0)
            XCTAssertTrue(store.isFailed)
            let restored = makeStore(defaults, uptime: { uptime })
            XCTAssertEqual(restored.run, expiredRun)
            XCTAssertEqual(restored.timeRushMazeNumber, 2)
            XCTAssertTrue(restored.isFailed)
        }
    }

    func testActiveLegacyCourseKeepsExactTimerRewardsPaintAndStageOnRelaunch() throws {
        for stageIndex in [0, 2] {
            try withDefaults { defaults in
                let course = legacyCourse()
                let session = TimeRushSession(course: course, stageIndex: stageIndex)
                var run = MazeRun(level: session.currentLevel)
                run.move(try XCTUnwrap(run.hintDirection))
                let clock = TimedRunState(remainingSeconds: 347.25, hasStarted: true, rewardedExtensions: 2)
                let progress = preservedProgress()
                try saveTimedSnapshot(defaults, session: session, run: run, clock: clock, progress: progress)

                let restored = makeStore(defaults)
                XCTAssertEqual(restored.timeRushSession, session)
                XCTAssertEqual(restored.run, run)
                XCTAssertEqual(restored.clock, clock)
                XCTAssertEqual(restored.timeRushMazeNumber, stageIndex + 1)
                XCTAssertEqual(restored.progress, progress)
                restored.switchMode(.endless)
                restored.switchMode(.timed)
                XCTAssertEqual(restored.timeRushSession, session)
                XCTAssertEqual(restored.run, run)
                XCTAssertEqual(restored.clock, clock)
            }
        }
    }

    func testRestartLegacyCourseAdoptsTighterTimerWithoutRegeneratingItsMazes() throws {
        try withDefaults { defaults in
            let course = legacyCourse()
            let expected = course.retimed()
            let session = TimeRushSession(course: course, stageIndex: 2)
            var run = MazeRun(level: session.currentLevel)
            run.move(try XCTUnwrap(run.hintDirection))
            let clock = TimedRunState(remainingSeconds: 143.5, hasStarted: true, rewardedExtensions: 3)
            let progress = preservedProgress()
            try saveTimedSnapshot(defaults, session: session, run: run, clock: clock, progress: progress)
            let restored = makeStore(defaults)
            let previousRunID = restored.runID
            let previousReward = try XCTUnwrap(restored.rewardRequest(.extraTime))

            restored.replay()

            XCTAssertLessThan(expected.timeLimit, course.timeLimit)
            XCTAssertEqual(restored.timeRushSession, TimeRushSession(course: expected))
            XCTAssertEqual(restored.run, MazeRun(level: expected.levels[0]))
            XCTAssertEqual(restored.clock, TimedRunState(remainingSeconds: expected.timeLimit))
            XCTAssertEqual(restored.timeRushMazeNumber, 1)
            XCTAssertNotEqual(restored.runID, previousRunID)
            XCTAssertEqual(restored.progress, progress)
            assertSameCourseMazes(course, try XCTUnwrap(restored.timeRushSession?.course))
            restored.applyReward(previousReward)
            XCTAssertEqual(restored.clock, TimedRunState(remainingSeconds: expected.timeLimit))

            let relaunched = makeStore(defaults)
            XCTAssertEqual(relaunched.timeRushSession, restored.timeRushSession)
            XCTAssertEqual(relaunched.run, restored.run)
            XCTAssertEqual(relaunched.clock, restored.clock)
        }
    }

    func testUnstartedLegacyCourseAdoptsAndPersistsTighterBudgetOnRestore() throws {
        try withDefaults { defaults in
            let course = legacyCourse()
            let expected = course.retimed()
            let progress = preservedProgress()
            try saveTimedSnapshot(defaults, session: TimeRushSession(course: course),
                                  run: MazeRun(level: course.levels[0]),
                                  clock: TimedRunState(remainingSeconds: course.timeLimit), progress: progress)

            let restored = GameStore(defaults: defaults)

            XCTAssertLessThan(expected.timeLimit, course.timeLimit)
            XCTAssertEqual(restored.timeRushSession, TimeRushSession(course: expected))
            XCTAssertEqual(restored.run, MazeRun(level: expected.levels[0]))
            XCTAssertEqual(restored.clock, TimedRunState(remainingSeconds: expected.timeLimit))
            XCTAssertEqual(restored.progress, progress)
            assertSameCourseMazes(course, try XCTUnwrap(restored.timeRushSession?.course))
            let persisted = try JSONDecoder().decode(GameSnapshot.self, from: XCTUnwrap(defaults.data(forKey: "prism.snapshot.v2")))
            XCTAssertEqual(persisted.timeRushSession, restored.timeRushSession)
            XCTAssertEqual(persisted.runs["timed"], restored.run)
            XCTAssertEqual(persisted.clocks["timed"], restored.clock)

            let relaunched = makeStore(defaults)
            XCTAssertEqual(relaunched.timeRushSession, restored.timeRushSession)
            XCTAssertEqual(relaunched.clock, restored.clock)
        }
    }

    func testUnstartedLegacyCourseKeepsEarnedExtraTimeWhenItsBudgetChanges() throws {
        try withDefaults { defaults in
            let course = legacyCourse()
            let expected = course.retimed()
            let clock = TimedRunState(remainingSeconds: course.timeLimit + 60, rewardedExtensions: 2)
            try saveTimedSnapshot(defaults, session: TimeRushSession(course: course),
                                  run: MazeRun(level: course.levels[0]), clock: clock)

            let restored = makeStore(defaults)
            let expectedClock = TimedRunState(remainingSeconds: expected.timeLimit + 60, rewardedExtensions: 2)
            XCTAssertEqual(restored.timeRushSession?.course, expected)
            XCTAssertEqual(restored.clock, expectedClock)
            XCTAssertFalse(try XCTUnwrap(restored.clock).hasStarted)
            restored.switchMode(.endless)
            restored.switchMode(.timed)
            XCTAssertEqual(restored.clock, expectedClock, "Restoring the same course must not add or remove rewards again")
            let relaunched = makeStore(defaults)
            XCTAssertEqual(relaunched.clock, expectedClock)
        }
    }

    func testLegacyCourseWaitingInAnotherModeRetimesWhenOpened() throws {
        try withDefaults { defaults in
            let course = legacyCourse()
            try saveTimedSnapshot(defaults, session: TimeRushSession(course: course),
                                  run: MazeRun(level: course.levels[0]),
                                  clock: TimedRunState(remainingSeconds: course.timeLimit), mode: .endless)
            let restored = makeStore(defaults)
            XCTAssertFalse(restored.isTimeRush)

            restored.switchMode(.timed)

            let expected = course.retimed()
            XCTAssertEqual(restored.timeRushSession, TimeRushSession(course: expected))
            XCTAssertEqual(restored.run, MazeRun(level: expected.levels[0]))
            XCTAssertEqual(restored.clock, TimedRunState(remainingSeconds: expected.timeLimit))
        }
    }

    func testSwitchingModesDailyAndDuelPreservesTimedCourseWithoutChargingAwayTime() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults, uptime: { uptime })
            store.move(try XCTUnwrap(store.run.hintDirection))
            let classicRun = store.run
            store.switchMode(.timed)
            try completeMaze(store)
            XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
            store.move(try XCTUnwrap(store.run.hintDirection))
            uptime += 1.75
            store.tick()
            let timedRun = store.run
            let timedClock = store.clock
            let session = store.timeRushSession

            store.switchMode(.endless)
            XCTAssertEqual(store.run, classicRun)
            XCTAssertFalse(store.isTimeRush)
            uptime += 1_000
            let restored = makeStore(defaults, uptime: { uptime })
            restored.switchMode(.timed)
            XCTAssertEqual(restored.run, timedRun)
            XCTAssertEqual(restored.clock, timedClock)
            XCTAssertEqual(restored.timeRushSession, session)
            restored.openDaily()
            restored.move(try XCTUnwrap(restored.run.hintDirection))
            let dailyRun = restored.run
            uptime += 1_000
            let dailyRestored = makeStore(defaults, uptime: { uptime })
            XCTAssertTrue(dailyRestored.isDaily)
            XCTAssertFalse(dailyRestored.isTimeRush)
            XCTAssertEqual(dailyRestored.run, dailyRun)
            dailyRestored.endSpecialSession()
            XCTAssertEqual(dailyRestored.run, timedRun)
            XCTAssertEqual(dailyRestored.clock, timedClock)
            XCTAssertEqual(dailyRestored.timeRushSession, session)
            dailyRestored.openDuel(seed: 11, id: "time-rush-persistence")
            XCTAssertFalse(dailyRestored.isTimeRush)
            uptime += 1_000
            dailyRestored.endSpecialSession()
            XCTAssertEqual(dailyRestored.run, timedRun)
            XCTAssertEqual(dailyRestored.clock, timedClock)
            XCTAssertEqual(dailyRestored.timeRushSession, session)
        }
    }

    func testRelaunchBetweenMazesRestoresPendingTransitionInsteadOfRepeatingPrizeOrTimer() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults)
            store.switchMode(.timed)
            try completeMaze(store)
            let remaining = store.clock
            let restored = makeStore(defaults)
            XCTAssertTrue(restored.run.isComplete)
            XCTAssertTrue(restored.isAwaitingTimeRushMaze)
            XCTAssertFalse(restored.hasEnded)
            XCTAssertFalse(restored.clockRunning)
            XCTAssertEqual(restored.clock, remaining)
            XCTAssertEqual(restored.progress.points, 0)
            XCTAssertEqual(restored.timeRushMazesCompleted, 1)
            XCTAssertTrue(restored.advanceTimeRushMaze(after: restored.runID))
            XCTAssertEqual(restored.timeRushMazeNumber, 2)
            XCTAssertEqual(restored.clock, remaining)
        }
    }

    func testLegacySnapshotMigratesTimedBoardWithoutLosingOtherProgress() throws {
        try withDefaults { defaults in
            var progress = ProgressData()
            progress.completeLevel(.generate(number: 1, mode: .timed))
            progress.claimAdBonus(level: .generate(number: 1, mode: .timed))
            progress.endlessLevel = 8
            progress.challengeLevel = 5
            progress.timedLevel = 9
            progress.points = 987
            progress.ownedSkinIDs = ["coral", "mint"]
            progress.selectedSkinID = "mint"
            progress.hapticsEnabled = false
            progress.soundEnabled = false
            progress.directionButtonsEnabled = true
            progress.tutorialDismissed = true
            var classic = MazeRun(level: .generate(number: 8, mode: .endless))
            classic.move(try XCTUnwrap(classic.hintDirection))
            var challenge = MazeRun(level: .generate(number: 5, mode: .challenge))
            challenge.move(try XCTUnwrap(challenge.hintDirection))
            var timed = MazeRun(level: .generate(number: 4, mode: .timed))
            timed.move(try XCTUnwrap(timed.hintDirection))
            let snapshot = GameSnapshot(
                progress: progress, runs: ["endless": classic, "challenge": challenge, "timed": timed],
                clocks: ["timed": TimedRunState(remainingSeconds: 7.25, hasStarted: true, rewardedExtensions: 2)],
                mode: .timed, dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora"
            )
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
            payload.removeValue(forKey: "timeRushSession")
            defaults.set(try JSONSerialization.data(withJSONObject: payload), forKey: "prism.snapshot.v2")

            let restored = makeStore(defaults)
            XCTAssertTrue(restored.isTimeRush)
            XCTAssertEqual(restored.run.level.number, 4)
            XCTAssertEqual(restored.timeRushMazeNumber, 1)
            XCTAssertGreaterThanOrEqual(restored.timeRushMazeCount, 5)
            XCTAssertEqual(restored.run.moves, 0)
            XCTAssertFalse(try XCTUnwrap(restored.clock).hasStarted)
            XCTAssertEqual(restored.clock?.rewardedExtensions, 0)
            XCTAssertEqual(restored.progress, progress)
            restored.switchMode(.endless)
            XCTAssertEqual(restored.run, classic)
            restored.switchMode(.challenge)
            XCTAssertEqual(restored.run, challenge)
            restored.switchMode(.timed)
            restored.openLevel(1)
            try completeCourse(restored)
            XCTAssertEqual(restored.earnedPoints, 0, "The redesign must not erase the existing timed completion ledger")
            // A replay adds move records while preserving every legacy ledger,
            // preference, unlock, and wallet field.
            var replayed = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored.progress)) as? [String: Any])
            var original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as? [String: Any])
            replayed.removeValue(forKey: "levelRecords")
            original.removeValue(forKey: "levelRecords")
            XCTAssertEqual(replayed as NSDictionary, original as NSDictionary)
        }
    }

    private func assertTimedCadence(number: Int, secondsPerSwipe: TimeInterval, completes: Bool,
                                    file: StaticString = #filePath, line: UInt = #line) throws -> Int {
        var acceptedMoves = 0
        try withDefaults { defaults in
            var progress = ProgressData()
            progress.timedLevel = number
            defaults.set(try JSONEncoder().encode(progress), forKey: "prism.progress")
            var uptime = 0.0
            let store = makeStore(defaults, uptime: { uptime })
            store.switchMode(.timed)
            store.setPresentationReady(false, for: store.runID)
            let budget = try XCTUnwrap(store.clock?.remainingSeconds, file: file, line: line)
            XCTAssertEqual(store.timeRushMazeCount, 5, file: file, line: line)

            course: for stageIndex in 0..<store.timeRushMazeCount {
                let beforeLoading = store.clock
                uptime += 20
                store.tick()
                XCTAssertEqual(store.clock, beforeLoading, "Scene loading must not consume play time", file: file, line: line)
                store.setPresentationReady(true, for: store.runID)
                uptime += 1
                store.tick()
                if stageIndex == 0 {
                    XCTAssertEqual(store.clock?.remainingSeconds, budget, file: file, line: line)
                    XCTAssertFalse(try XCTUnwrap(store.clock).hasStarted, file: file, line: line)
                }
                let directions = store.run.level.solution
                for direction in directions {
                    if store.isFailed { break course }
                    if store.run.isComplete { break }
                    let previousMoves = store.run.moves
                    uptime += secondsPerSwipe
                    store.move(direction)
                    acceptedMoves += store.run.moves - previousMoves
                    if !store.isFailed {
                        XCTAssertEqual(store.run.moves, previousMoves + 1, "The stored route must execute real swipes", file: file, line: line)
                    }
                }
                if store.isFailed { break }
                XCTAssertTrue(store.run.isComplete, file: file, line: line)
                if stageIndex < store.timeRushMazeCount - 1 {
                    XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID), file: file, line: line)
                }
            }

            XCTAssertEqual(store.clock?.rewardedExtensions, 0, file: file, line: line)
            XCTAssertTrue(store.hasEnded, file: file, line: line)
            if completes {
                XCTAssertFalse(store.isFailed, file: file, line: line)
                XCTAssertEqual(store.timeRushMazesCompleted, 5, file: file, line: line)
                XCTAssertGreaterThan(try XCTUnwrap(store.clock?.remainingSeconds), 0, file: file, line: line)
                XCTAssertEqual(store.progress.completedLevels, 1, file: file, line: line)
                XCTAssertEqual(store.progress.timedLevel, number + 1, file: file, line: line)
            } else {
                XCTAssertTrue(store.isFailed, file: file, line: line)
                XCTAssertLessThan(store.timeRushMazesCompleted, 5, file: file, line: line)
                XCTAssertEqual(store.clock?.remainingSeconds, 0, file: file, line: line)
                XCTAssertEqual(store.progress.completedLevels, 0, file: file, line: line)
                XCTAssertEqual(store.progress.timedLevel, number, file: file, line: line)
            }
        }
        return acceptedMoves
    }

    private func completeMaze(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) throws {
        for _ in 0..<500 {
            guard !store.run.isComplete else { return }
            store.move(try XCTUnwrap(store.run.hintDirection, file: file, line: line))
        }
        XCTFail("The maze did not complete within its bounded solution", file: file, line: line)
    }

    private func legacyCourse() -> TimeRushCourse {
        let course = TimeRushCourse.generate(number: 1)
        let levels = course.levels.map { level in
            MazeLevel(number: level.number, mode: level.mode, width: level.width, height: level.height,
                      openCells: level.openCells, start: level.start, solution: level.solution,
                      moveLimit: level.moveLimit, timeLimit: 600, coinCells: level.coinCells)
        }
        return TimeRushCourse(number: course.number, levels: levels, timeLimit: 600)
    }

    private func preservedProgress() -> ProgressData {
        var progress = ProgressData()
        progress.points = 987
        progress.endlessLevel = 8
        progress.challengeLevel = 5
        progress.timedLevel = 9
        progress.ownedSkinIDs = ["coral", "mint"]
        progress.selectedSkinID = "mint"
        progress.hapticsEnabled = false
        progress.soundEnabled = false
        return progress
    }

    private func saveTimedSnapshot(_ defaults: UserDefaults, session: TimeRushSession, run: MazeRun,
                                   clock: TimedRunState, progress: ProgressData = ProgressData(),
                                   mode: GameMode = .timed) throws {
        let snapshot = GameSnapshot(progress: progress, runs: ["timed": run], clocks: ["timed": clock],
                                    mode: mode, dailyRun: nil, dailyID: nil, dailyActive: false,
                                    themeID: "aurora", timeRushSession: session)
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
    }

    private func assertSameCourseMazes(_ original: TimeRushCourse, _ updated: TimeRushCourse,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(updated.number, original.number, file: file, line: line)
        XCTAssertEqual(updated.mazeCount, original.mazeCount, file: file, line: line)
        for (before, after) in zip(original.levels, updated.levels) {
            XCTAssertEqual(after.number, before.number, file: file, line: line)
            XCTAssertEqual(after.mode, before.mode, file: file, line: line)
            XCTAssertEqual(after.width, before.width, file: file, line: line)
            XCTAssertEqual(after.height, before.height, file: file, line: line)
            XCTAssertEqual(after.openCells, before.openCells, file: file, line: line)
            XCTAssertEqual(after.start, before.start, file: file, line: line)
            XCTAssertEqual(after.solution, before.solution, file: file, line: line)
            XCTAssertEqual(after.coinCells, before.coinCells, file: file, line: line)
            XCTAssertEqual(after.moveLimit, before.moveLimit, file: file, line: line)
            XCTAssertEqual(after.timeLimit, updated.timeLimit, file: file, line: line)
        }
    }

    private func completeCourse(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) throws {
        let count = store.timeRushMazeCount
        XCTAssertGreaterThan(count, 1, file: file, line: line)
        for index in 0..<count {
            try completeMaze(store, file: file, line: line)
            if index < count - 1 {
                XCTAssertFalse(store.hasEnded, file: file, line: line)
                XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID), file: file, line: line)
            }
        }
        XCTAssertTrue(store.hasEnded, file: file, line: line)
    }

    private func makeStore(_ defaults: UserDefaults, uptime: @escaping () -> TimeInterval = { 0 }) -> GameStore {
        let store = GameStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_788_696_000) }, uptime: uptime)
        store.setHaptics(false)
        store.setSound(false)
        return store
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.TimeRushSessionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
#endif
