import SwiftUI
import AudioToolbox
import Combine

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var progress: ProgressData
    @Published private(set) var run: MazeRun
    @Published private(set) var mode: GameMode
    @Published private(set) var runID = UUID()
    @Published private(set) var inputID = UUID()
    /// Direct delivery preserves every accepted turn between SwiftUI display updates.
    let moveEvents = PassthroughSubject<GameMoveEvent, Never>()
    /// Snapshot the completed board before any next-run state reaches SwiftUI.
    let levelTransitionEvents = PassthroughSubject<UUID, Never>()
    @Published private(set) var clock: TimedRunState?
    @Published private(set) var timeRushSession: TimeRushSession?
    @Published private(set) var dailyChallenge: DailyChallenge
    @Published private(set) var isDaily = false
    @Published private(set) var duelID: String?
    @Published var theme: BoardTheme { didSet { save() } }
    @Published var hint: MoveDirection?
    @Published private(set) var blockedDirection: MoveDirection?
    @Published var notice: String?
    @Published private(set) var earnedPoints = 0
    @Published private(set) var isRewardPending = false
    private let defaults: UserDefaults
    private let snapshotEncoder = GameSnapshotEncoder()
    private let dateProvider: () -> Date
    private let uptimeProvider: () -> TimeInterval
    private var savedRuns: [String: MazeRun]
    private var savedClocks: [String: TimedRunState]
    private var savedDailyRun: MazeRun?
    private var lastTick: TimeInterval?
    private var appActive = true
    private var playVisible = true
    private var modalOpen = false
    private var presentationReady = true
    private var tracksPresentationReadiness = false
    private var rewardedRequestIDs: Set<UUID> = []
    private var completionVerification: (runID: UUID, task: Task<MazeOptimality.Result, Never>)?
    private let feedback = UIImpactFeedbackGenerator(style: .soft)

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.defaults = defaults
        dateProvider = now
        uptimeProvider = uptime
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            for key in ["prism.snapshot.v2", "prism.progress", "prism.runs", "prism.mode"] { defaults.removeObject(forKey: key) }
        }
#endif
        let decoder = JSONDecoder()
        let snapshot = defaults.data(forKey: "prism.snapshot.v2").flatMap { try? decoder.decode(GameSnapshot.self, from: $0) }
        var loadedProgress = snapshot?.progress ?? defaults.data(forKey: "prism.progress").flatMap {
            try? decoder.decode(ProgressData.self, from: $0)
        } ?? ProgressData()
#if DEBUG
        // Exercise expensive collection purchases without thousands of UI swipes.
        // A wallet fixture is accepted only alongside the destructive test reset.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"),
           let flag = arguments.firstIndex(of: "--ui-test-coins"),
           arguments.indices.contains(flag + 1),
           let coins = Int(arguments[flag + 1]),
           (0...150_000).contains(coins) {
            loadedProgress.points = coins
        }
#endif
        var loadedRuns = snapshot?.runs ?? defaults.data(forKey: "prism.runs").flatMap {
            try? decoder.decode([String: MazeRun].self, from: $0)
        } ?? [:]
        var loadedClocks = snapshot?.clocks ?? [:]
        var loadedSession = snapshot?.timeRushSession
        var refreshedGrid = false
        // Older releases saved their generated geometry. Bring only differing
        // grids onto the shared catalog; matching runs retain their exact state.
        for soloMode in [GameMode.endless, .challenge] {
            guard let saved = loadedRuns[soloMode.rawValue] else { continue }
            let canonical = MazeLevel.generate(number: saved.level.number, mode: soloMode)
            if saved.level.mode != soloMode || !saved.level.hasSameGrid(as: canonical) {
                var refreshed = MazeRun(level: canonical)
                refreshed.grantExtraMoves(count: saved.extraMovesGranted)
                loadedRuns[soloMode.rawValue] = refreshed
                loadedClocks.removeValue(forKey: soloMode.rawValue)
                refreshedGrid = true
            }
        }
        if let session = loadedSession, session.isValid {
            let canonical = TimeRushCourse.generate(number: session.course.number)
            if !zip(session.course.levels, canonical.levels).allSatisfy({ $0.hasSameGrid(as: $1) }) {
                loadedSession = TimeRushSession(course: canonical)
                loadedRuns[GameMode.timed.rawValue] = MazeRun(level: canonical.levels[0])
                let extensions = max(0, loadedClocks[GameMode.timed.rawValue]?.rewardedExtensions ?? 0)
                loadedClocks[GameMode.timed.rawValue] = TimedRunState(
                    remainingSeconds: canonical.timeLimit + Double(extensions) * 30,
                    rewardedExtensions: extensions
                )
                refreshedGrid = true
            }
        }
        let loadedMode = snapshot?.mode ?? GameMode(rawValue: defaults.string(forKey: "prism.mode") ?? "endless") ?? .endless
        let daily = DailyChallenge.generate(for: now())
        let resumeDaily = snapshot?.dailyActive == true && snapshot?.dailyID == daily.id
        progress = loadedProgress
        savedRuns = loadedRuns
        savedClocks = loadedClocks
        timeRushSession = loadedSession
        savedDailyRun = snapshot?.dailyID == daily.id ? snapshot?.dailyRun : nil
        dailyChallenge = daily
        mode = loadedMode
        isDaily = resumeDaily
        theme = BoardTheme(rawValue: snapshot?.themeID ?? "aurora") ?? .aurora
        let frontier: Int
        switch loadedMode {
        case .endless: frontier = loadedProgress.endlessLevel
        case .challenge: frontier = loadedProgress.challengeLevel
        case .timed: frontier = loadedProgress.timedLevel
        }
        let loadedRun = resumeDaily ? (snapshot?.dailyRun ?? MazeRun(level: daily.level)) :
            (loadedRuns[loadedMode.rawValue] ?? MazeRun(level: .generate(number: frontier, mode: loadedMode)))
        run = loadedRun
        clock = resumeDaily ? nil : loadedClocks[loadedMode.rawValue] ?? loadedRun.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        lastTick = uptime()
        if !resumeDaily && loadedMode == .timed { restoreSoloRun() }
        if refreshedGrid { save() }
        startCompletionVerification()
    }

    var skin: BallSkin { BallSkin.catalog.first { $0.id == progress.selectedSkinID } ?? BallSkin.catalog[0] }
    var fraction: Double { Double(run.painted.count) / Double(max(run.level.openCells.count, 1)) }
    var isDuel: Bool { duelID != nil }
    var isTimeRush: Bool { mode == .timed && !isDaily && !isDuel }
    var timeRushMazeNumber: Int { (timeRushSession?.stageIndex ?? 0) + 1 }
    var timeRushMazeCount: Int { timeRushSession?.course.mazeCount ?? 5 }
    var timeRushMazesCompleted: Int { timeRushMazeNumber - 1 + (run.isComplete ? 1 : 0) }
    var isAwaitingTimeRushMaze: Bool { isTimeRush && run.isComplete && timeRushMazeNumber < timeRushMazeCount }
    var timeExpired: Bool { clock.map { $0.hasStarted && $0.remainingSeconds <= 0 } ?? false }
    var isFailed: Bool { !run.isComplete && (run.isFailed || timeExpired) }
    var hasEnded: Bool { (run.isComplete && !isAwaitingTimeRushMaze) || isFailed }
    var offersIntroductoryHints: Bool {
        !isDaily && !isDuel && mode == .endless && run.level.number == 1
            && !hasEnded && !progress.hasCompleted(run.level)
    }
    var showsTutorial: Bool { offersIntroductoryHints && !progress.tutorialDismissed }
    var bonusClaimed: Bool { progress.hasClaimedAdBonus(level: run.level) }
    var canClaimAdBonus: Bool { !isDaily && !isDuel && run.isComplete && hasEnded && progress.hasCompleted(run.level) && !bonusClaimed }
    var currentUnlockedLevel: Int {
        switch mode {
        case .endless: progress.endlessLevel
        case .challenge: progress.challengeLevel
        case .timed: progress.timedLevel
        }
    }
    var timerText: String {
        let seconds = Int(ceil(max(0, clock?.remainingSeconds ?? 0)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var currentStreak: Int { progress.dailyCurrentStreak(at: dateProvider()) }
    var canClaimDaily: Bool { progress.canClaimDailyReward(at: dateProvider()) }
    var dailyReward: Int { progress.dailyRewardAmount(at: dateProvider()) }
    var clockRunning: Bool { appActive && playVisible && presentationReady && !modalOpen && !isRewardPending && !hasEnded && !run.isComplete && clock?.hasStarted == true }
    var acceptsGameplayInput: Bool { appActive && playVisible && presentationReady && !modalOpen && notice == nil && !hasEnded && !run.isComplete && !isRewardPending }

    func tick() {
        if appActive { refreshDaily() }
        let now = uptimeProvider()
        defer { lastTick = now }
        guard let previous = lastTick, clockRunning, var current = clock else { return }
        let oldSecond = Int(current.remainingSeconds)
        current.consume(now - previous)
        clock = current
        if oldSecond != Int(current.remainingSeconds) { save() }
    }

    func setActivity(active: Bool? = nil, visible: Bool? = nil, modal: Bool? = nil) {
        tick()
        let changed = active.map { $0 != appActive } == true || visible.map { $0 != playVisible } == true || modal.map { $0 != modalOpen } == true
        if let active { appActive = active }
        if let visible { playVisible = visible }
        if let modal { modalOpen = modal }
        if changed { inputID = UUID() }
        lastTick = uptimeProvider()
        save()
    }

    /// The UI opts into readiness tracking; headless consumers have no scene to wait for.
    func setPresentationReady(_ ready: Bool, for runID: UUID) {
        guard runID == self.runID else { return }
        tick()
        guard runID == self.runID else { return }
        tracksPresentationReadiness = true
        guard presentationReady != ready else { return }
        presentationReady = ready
        inputID = UUID()
        lastTick = uptimeProvider()
        save()
    }

    func refreshDaily() {
        let date = dateProvider()
        guard DailyCalendar.dayID(for: date, calendar: .current) != dailyChallenge.id else { return }
        let wasDaily = isDaily
        if wasDaily { endSpecialSession() }
        dailyChallenge = DailyChallenge.generate(for: date)
        savedDailyRun = nil
        if wasDaily { notice = "A new day has started. Today's fresh daily maze is ready in Challenges." }
        save()
    }

    func move(_ direction: MoveDirection) {
        move(direction, for: inputID)
    }

    func move(_ direction: MoveDirection, for inputID: UUID) {
        guard inputID == self.inputID else { return }
        let originalRun = runID
        tick()
        guard inputID == self.inputID, originalRun == runID, acceptsGameplayInput else { return }
        let start = run.position
        let path = run.move(direction)
        guard !path.isEmpty else {
            blockedDirection = direction
            hint = nil
            if progress.hapticsEnabled { feedback.impactOccurred(intensity: 0.25) }
            return
        }
        blockedDirection = nil
        moveEvents.send(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                     painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        clock?.hasStarted = true
        lastTick = uptimeProvider()
        hint = nil
        if !isDaily && !isDuel { progress.awardCollectedCoins(for: run) }
        if progress.soundEnabled { AudioServicesPlaySystemSound(1104) }
        if run.isComplete {
            if !isAwaitingTimeRushMaze {
                earnedPoints = isDuel ? 0 : isDaily ? progress.completeDailyChallenge(dailyChallenge, at: dateProvider()) : progress.completeLevel(run.level)
            }
            startCompletionVerification()
        }
        save()
    }

    func switchMode(_ next: GameMode) {
        guard next != mode || isDaily || isDuel else { return }
        tick(); cacheCurrentRun()
        isDaily = false; duelID = nil; mode = next
        restoreSoloRun()
        clearTransientState(); save()
    }

    func replay() {
        if isTimeRush, let previous = timeRushSession {
            let session = TimeRushSession(course: previous.course.retimed())
            timeRushSession = session
            run = MazeRun(level: session.currentLevel)
            clock = freshClock(limit: session.course.timeLimit)
        } else {
            run.reset()
            clock = freshClock(limit: run.level.timeLimit)
        }
        clearTransientState(); save()
    }

    func nextLevel() {
        if isDaily || isDuel { endSpecialSession(); return }
        let following = run.level.number == Int.max ? Int.max : run.level.number + 1
        let number = max(following, currentUnlockedLevel)
        if isTimeRush { startTimeRush(number: number) }
        else {
            run = MazeRun(level: .generate(number: number, mode: mode))
            clock = freshClock(limit: run.level.timeLimit)
        }
        clearTransientState(); save()
    }

    /// A rendered completion or ad callback can advance only its own finished run.
    @discardableResult
    func advanceCompletedLevel(for completedRunID: UUID) -> Bool {
        guard completedRunID == runID, run.isComplete, hasEnded, !isDuel else { return false }
        levelTransitionEvents.send(completedRunID)
        nextLevel()
        return true
    }

    func openLevel(_ number: Int) {
        guard number >= 1, number <= currentUnlockedLevel else { return }
        tick(); cacheCurrentRun()
        isDaily = false; duelID = nil
        if isTimeRush {
            if let session = timeRushSession, session.isValid, session.course.number == number,
               let saved = savedRuns[mode.rawValue], saved.level == session.currentLevel,
               !saved.isComplete || session.stageIndex < session.course.mazeCount - 1 {
                restoreSoloRun()
            } else {
                startTimeRush(number: number)
            }
        } else if let saved = savedRuns[mode.rawValue], saved.level.number == number, !saved.isComplete {
            run = saved
            clock = savedClocks[mode.rawValue] ?? saved.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        } else {
            run = MazeRun(level: .generate(number: number, mode: mode))
            clock = run.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        }
        clearTransientState(); save()
    }

    func openDaily(replayCompleted: Bool = false) {
        tick(); cacheCurrentRun()
        isDaily = true; duelID = nil
        run = savedDailyRun ?? MazeRun(level: dailyChallenge.level)
        if replayCompleted && run.isComplete { run.reset() }
        clock = nil
        clearTransientState(); save()
    }

    func openDuel(seed: Int, id: String) {
        tick(); cacheCurrentRun()
        isDaily = false; duelID = id
        run = MazeRun(level: .generate(number: seed, mode: .endless))
        clock = nil
        clearTransientState(); save()
    }

    func endSpecialSession() {
        cacheCurrentRun()
        isDaily = false; duelID = nil
        restoreSoloRun()
        clearTransientState(); save()
    }

    func showHint() {
        guard !hasEnded, !run.isComplete, !isDuel else { return }
        blockedDirection = nil
        hint = run.hintDirection
    }

    func rewardRequest(_ kind: GameplayReward) -> GameplayRewardRequest? {
        let originalRun = runID
        tick()
        guard originalRun == runID, !isDuel else { return nil }
        switch kind {
        case .hint: guard !hasEnded, !run.isComplete else { return nil }
        case .extraTime: guard clock != nil, !run.isComplete else { return nil }
        case .extraMoves: guard run.remainingMoves != nil, !run.isComplete else { return nil }
        case .skip: guard !isDaily, !run.isComplete else { return nil }
        }
        return GameplayRewardRequest(id: UUID(), runID: runID, kind: kind, position: run.position, moves: run.moves)
    }

    func beginReward() { tick(); isRewardPending = true; inputID = UUID(); save() }
    func finishReward() { isRewardPending = false; inputID = UUID(); lastTick = uptimeProvider() }

    func applyReward(_ request: GameplayRewardRequest) {
        guard request.runID == runID, rewardedRequestIDs.insert(request.id).inserted else { return }
        switch request.kind {
        case .hint:
            guard request.position == run.position, request.moves == run.moves else { return }
            showHint()
        case .extraTime: clock?.extend(by: 30)
        case .extraMoves: _ = run.grantExtraMoves(count: 3)
        case .skip:
            let next = run.level.number == Int.max ? Int.max : run.level.number + 1
            switch mode {
            case .endless: progress.endlessLevel = max(progress.endlessLevel, next)
            case .challenge: progress.challengeLevel = max(progress.challengeLevel, next)
            case .timed: progress.timedLevel = max(progress.timedLevel, next)
            }
            nextLevel()
        }
        lastTick = uptimeProvider(); save()
    }

    func claimDaily() {
        refreshDaily()
        let amount = progress.claimDailyReward(at: dateProvider())
        if amount > 0 { notice = "+\(amount) coins! Day \(currentStreak) of your streak." }
        save()
    }
    func claimMilestone(_ id: String) {
        let amount = progress.claimMilestone(id: id)
        if amount > 0 { notice = "Challenge complete. +\(amount) coins!" }
        save()
    }
    func selectSkin(_ skin: BallSkin) {
        if progress.purchaseSkin(skin) {
            if progress.hapticsEnabled { feedback.impactOccurred() }
        } else { notice = "Earn \(max(0, skin.price - progress.points)) more coins to unlock \(skin.name)." }
        save()
    }
    func claimAdBonus(for level: MazeLevel) { progress.claimAdBonus(level: level); save() }
    func setHaptics(_ enabled: Bool) { progress.hapticsEnabled = enabled; save() }
    func setSound(_ enabled: Bool) { progress.soundEnabled = enabled; save() }
    func setDirectionButtons(_ enabled: Bool) { progress.directionButtonsEnabled = enabled; save() }
    func dismissTutorial() { progress.tutorialDismissed = true; save() }

    private func clearTransientState() {
        runID = UUID(); inputID = UUID(); earnedPoints = 0; hint = nil; notice = nil
        blockedDirection = nil
        isRewardPending = false; rewardedRequestIDs.removeAll(); lastTick = uptimeProvider()
        if tracksPresentationReadiness { presentationReady = false }
        startCompletionVerification()
    }

    /// Presentation shares the store's work; leaving Play cannot lose a crown.
    func completedRunOptimality(for completedRunID: UUID) async -> MazeOptimality.Result {
        guard completedRunID == runID, run.isComplete else { return .incomplete }
        startCompletionVerification()
        guard let verification = completionVerification, verification.runID == completedRunID else { return .undetermined }
        return await verification.task.value
    }

    private func startCompletionVerification() {
        guard run.isComplete, completionVerification?.runID != runID else { return }
        let finishedRun = run
        let savesLevelProgress = !isDaily && !isDuel
        let stageIndex = isTimeRush ? timeRushSession?.stageIndex : nil
        if savesLevelProgress {
            progress.recordCompletedRun(finishedRun, stageIndex: stageIndex)
            save()
        }
        let verification = Task.detached(priority: .userInitiated) {
            MazeOptimality.verify(finishedRun)
        }
        let task = Task { [weak self] in
            let result = await verification.value
            if let self, savesLevelProgress {
                // Use the captured board and stage even if another level is now open.
                self.progress.recordCompletedRun(finishedRun, optimality: result, stageIndex: stageIndex)
                self.save()
            }
            return result
        }
        completionVerification = (runID, task)
    }
    /// Advance only after the previous maze's final movement has been presented.
    /// Loading and presentation are excluded from the player's shared time budget.
    @discardableResult
    func advanceTimeRushMaze(after completedRunID: UUID) -> Bool {
        guard completedRunID == runID, isAwaitingTimeRushMaze,
              var session = timeRushSession, session.isValid,
              (clock?.remainingSeconds ?? 0) > 0 else { return false }
        levelTransitionEvents.send(completedRunID)
        session.stageIndex += 1
        timeRushSession = session
        run = MazeRun(level: session.currentLevel)
        clearTransientState()
        save()
        return true
    }

    private func startTimeRush(number: Int) {
        let session = TimeRushSession(course: .generate(number: number))
        timeRushSession = session
        run = MazeRun(level: session.currentLevel)
        clock = freshClock(limit: session.course.timeLimit)
    }

    private func restoreSoloRun() {
        let saved = savedRuns[mode.rawValue]
        if mode == .timed {
            if let session = timeRushSession, session.isValid,
               let saved, saved.level == session.currentLevel {
                run = saved
                clock = savedClocks[mode.rawValue] ?? freshClock(limit: session.course.timeLimit)
                if session.stageIndex == 0, clock?.hasStarted == false,
                   saved == MazeRun(level: session.currentLevel) {
                    // A round that has never started adopts the current pace. Keep
                    // time already earned from ads, even before the first swipe.
                    let course = session.course.retimed()
                    guard course != session.course else { return }
                    let previousBudget = freshClock(limit: session.course.timeLimit)?.remainingSeconds ?? session.course.timeLimit
                    let earnedTime = max(0, (clock?.remainingSeconds ?? 0) - previousBudget)
                    let extensions = clock?.rewardedExtensions ?? 0
                    timeRushSession = TimeRushSession(course: course)
                    run = MazeRun(level: course.levels[0])
                    clock = freshClock(limit: course.timeLimit)
                    clock?.remainingSeconds += earnedTime
                    clock?.rewardedExtensions = extensions
                    save()
                }
            } else {
                // Legacy single-maze saves start the new course at the same round.
                // The wallet, unlocks, and completion ledger remain unchanged.
                startTimeRush(number: saved?.level.number ?? currentUnlockedLevel)
            }
        } else {
            run = saved ?? MazeRun(level: .generate(number: currentUnlockedLevel, mode: mode))
            clock = savedClocks[mode.rawValue] ?? freshClock(limit: run.level.timeLimit)
        }
    }

    private func freshClock(limit: TimeInterval?) -> TimedRunState? {
        guard let limit else { return nil }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--short-timer") { return TimedRunState(remainingSeconds: 2) }
#endif
        return TimedRunState(remainingSeconds: limit)
    }
    private func cacheCurrentRun() {
        if isDuel { return }
        if isDaily { savedDailyRun = run; return }
        savedRuns[mode.rawValue] = run
        savedClocks[mode.rawValue] = clock
    }
    private func save() {
        cacheCurrentRun()
        let snapshot = GameSnapshot(progress: progress, runs: savedRuns, clocks: savedClocks, mode: mode,
                                    dailyRun: savedDailyRun, dailyID: dailyChallenge.id, dailyActive: isDaily, themeID: theme.rawValue,
                                    timeRushSession: timeRushSession)
        if let data = try? snapshotEncoder.encode(snapshot) { defaults.set(data, forKey: "prism.snapshot.v2") }
    }
}
