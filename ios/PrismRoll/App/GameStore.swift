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
    @Published private(set) var isPreparingOptimalHint = false
    @Published private(set) var isHintPending = false
    @Published private(set) var blockedDirection: MoveDirection?
    @Published var notice: String?
    @Published private(set) var earnedPoints = 0
    @Published private(set) var isRewardPending = false
    private let defaults: UserDefaults
    private let progressPersistence: ProgressPersistence
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
    private var coinRewardRequestID: UUID?
    private var completionVerification: (runID: UUID, task: Task<MazeOptimality.Result, Never>)?
    private var completionTasks: [UUID: Task<MazeOptimality.Result, Never>] = [:]
    private var completionResults: [UUID: Task<MazeOptimality.Result, Never>] = [:]
    private var nonpersistentCompletionIDs: Set<UUID> = []
    private var pendingCompletions: [PendingCompletion] = []
    private var completedOptimality: (runID: UUID, result: MazeOptimality.Result)?
    private let completionVerifier: @Sendable (MazeRun) async -> MazeOptimality.Result
    private let optimalHintSolver: @Sendable (MazeLevel, GridCell, Set<GridCell>) async -> MazeNativeOptimizer.Result?
    private var optimalHintTask: Task<Void, Never>?
    private var optimalHintRequestID = UUID()
    private let feedback = UIImpactFeedbackGenerator(style: .soft)

    init(defaults: UserDefaults = .standard, progressFileURL: URL? = nil, now: @escaping () -> Date = Date.init,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         completionVerifier: @escaping @Sendable (MazeRun) async -> MazeOptimality.Result = { run in
             guard let minimum = await MazeMinimumMoveCache.shared.minimumMoves(for: run.level) else {
                 return .undetermined
             }
             return run.moves == minimum ? .optimal : .notOptimal
         },
         optimalHintSolver: @escaping @Sendable (MazeLevel, GridCell, Set<GridCell>) async -> MazeNativeOptimizer.Result? = { level, position, painted in
             await MazeMinimumMoveCache.shared.solution(for: level, position: position, painted: painted)
         }) {
        self.defaults = defaults
        self.optimalHintSolver = optimalHintSolver
        progressPersistence = ProgressPersistence(url: progressFileURL ?? ProgressPersistence.defaultURL(for: defaults))
        dateProvider = now
        uptimeProvider = uptime
        self.completionVerifier = completionVerifier
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            for key in ["prism.snapshot.v2", "prism.progress", "prism.runs", "prism.mode"] { defaults.removeObject(forKey: key) }
            progressPersistence.resetForUITesting()
        }
#endif
        let decoder = JSONDecoder()
        let snapshot = defaults.data(forKey: "prism.snapshot.v2").flatMap { try? decoder.decode(GameSnapshot.self, from: $0) }
        pendingCompletions = snapshot?.pendingCompletions ?? []
        var loadedProgress = (try? progressPersistence.load()) ?? snapshot?.progress ?? defaults.data(forKey: "prism.progress").flatMap {
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
        if arguments.contains("--uitesting"),
           let flag = arguments.firstIndex(of: "--ui-test-level"),
           arguments.indices.contains(flag + 1),
           let number = Int(arguments[flag + 1]),
           (1...1_000).contains(number) {
            loadedProgress.endlessLevel = number
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
        resumeCompletionVerifications()
        startCompletionVerification()
        startOptimalHintPreparation()
    }

    deinit {
        optimalHintTask?.cancel()
        for task in completionTasks.values { task.cancel() }
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
        let path = run.move(direction, recomputeFallbackHint: false)
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
        refreshOptimalHintPreparation()
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
        if hasOptimalHint {
            hint = run.hintDirection
        } else {
            isHintPending = true
            startOptimalHintPreparation()
        }
    }

    var hasOptimalHint: Bool {
        !hasEnded && !isDuel && run.hintIsOptimal && run.hintDirection != nil
    }

    /// Await the current board's proof without blocking animation or input.
    @discardableResult
    func prepareOptimalHint() async -> Bool {
        startOptimalHintPreparation()
        let requestID = optimalHintRequestID
        await optimalHintTask?.value
        return requestID == optimalHintRequestID && hasOptimalHint
    }

    private func refreshOptimalHintPreparation() {
        optimalHintTask?.cancel()
        optimalHintTask = nil
        optimalHintRequestID = UUID()
        isPreparingOptimalHint = false
        isHintPending = false
        startOptimalHintPreparation()
    }

    private func startOptimalHintPreparation() {
        guard optimalHintTask == nil, !hasEnded, !run.isComplete, !isDuel, !hasOptimalHint else { return }
        let requestID = optimalHintRequestID
        let solvingRunID = runID
        let snapshot = run
        let solver = optimalHintSolver
        isPreparingOptimalHint = true
        optimalHintTask = Task { [weak self] in
            let result = await solver(snapshot.level, snapshot.position, snapshot.painted)
            guard !Task.isCancelled, let self,
                  self.optimalHintRequestID == requestID, self.runID == solvingRunID,
                  self.run.position == snapshot.position, self.run.painted == snapshot.painted else { return }
            self.optimalHintTask = nil
            self.isPreparingOptimalHint = false
            if case let .optimal(moves, route) = result, moves == route.count {
                _ = self.run.installOptimalRoute(route)
            }
            if self.isHintPending, self.hasOptimalHint { self.hint = self.run.hintDirection }
            self.isHintPending = false
        }
    }

    func rewardRequest(_ kind: GameplayReward) -> GameplayRewardRequest? {
        let originalRun = runID
        tick()
        guard originalRun == runID, !isDuel else { return nil }
        switch kind {
        case .hint: guard hasOptimalHint else { return nil }
        case .extraTime: guard clock != nil, !run.isComplete else { return nil }
        case .extraMoves: guard run.remainingMoves != nil, !run.isComplete else { return nil }
        case .skip: guard !isDaily, !run.isComplete else { return nil }
        }
        return GameplayRewardRequest(id: UUID(), runID: runID, kind: kind, position: run.position, moves: run.moves)
    }

    func beginReward() { tick(); isRewardPending = true; inputID = UUID(); save() }
    func finishReward() { isRewardPending = false; coinRewardRequestID = nil; inputID = UUID(); lastTick = uptimeProvider() }

    static let videoCoinReward = 50

    func beginCoinReward() -> UUID? {
        guard !isRewardPending, !isDuel else { return nil }
        let id = UUID()
        beginReward()
        coinRewardRequestID = id
        return id
    }

    /// Called only by the ad SDK's earned-reward callback for this presentation.
    @discardableResult
    func claimCoinReward(_ id: UUID) -> Int {
        guard isRewardPending, coinRewardRequestID == id else { return 0 }
        coinRewardRequestID = nil
        let (balance, overflow) = progress.points.addingReportingOverflow(Self.videoCoinReward)
        guard !overflow else { return 0 }
        let previous = progress
        progress.points = balance
        guard save() else { progress = previous; return 0 }
        return Self.videoCoinReward
    }

    /// Finish a verified consumable only after its balance and receipt ID have
    /// reached the same atomic file. Replayed StoreKit deliveries are harmless.
    func deliverCoinPurchase(_ purchase: CoinPurchase) throws -> CoinDeliveryResult {
        guard progressPersistence.supportsDurablePurchases else { throw CoinDeliveryError.storageUnavailable }
        guard !purchase.transactionID.isEmpty, purchase.quantity > 0,
              let pack = CoinPack.catalog.first(where: { $0.id == purchase.productID }) else {
            throw CoinDeliveryError.invalidPurchase
        }
        if progress.receivedCoinTransactionIDs.contains(purchase.transactionID) {
            try progressPersistence.persist(progress)
            return .alreadyDelivered
        }
        let (amount, amountOverflow) = pack.coins.multipliedReportingOverflow(by: purchase.quantity)
        let (balance, balanceOverflow) = progress.points.addingReportingOverflow(amount)
        guard !amountOverflow, !balanceOverflow, amount > 0 else { throw CoinDeliveryError.balanceLimit }
        var credited = progress
        credited.points = balance
        credited.receivedCoinTransactionIDs.insert(purchase.transactionID)
        try progressPersistence.persist(credited)
        progress = credited
        save()
        return .credited(amount)
    }

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
        startOptimalHintPreparation()
        lastTick = uptimeProvider(); save()
    }

    func claimDaily() {
        refreshDaily()
        let previous = progress
        let amount = progress.claimDailyReward(at: dateProvider())
        guard save() else { progress = previous; notice = "Your reward could not be saved. Please try again."; return }
        if amount > 0 { notice = "+\(amount) coins! Day \(currentStreak) of your streak." }
    }
    func claimMilestone(_ id: String) {
        let previous = progress
        let amount = progress.claimMilestone(id: id)
        guard save() else { progress = previous; notice = "Your reward could not be saved. Please try again."; return }
        if amount > 0, progress.hapticsEnabled { feedback.impactOccurred() }
    }
    func selectSkin(_ skin: BallSkin) {
        let previous = progress
        if progress.purchaseSkin(skin) {
            guard save() else { progress = previous; notice = "Your ball could not be saved. Please try again."; return }
            if progress.hapticsEnabled { feedback.impactOccurred() }
        } else { notice = "Earn \(max(0, skin.price - progress.points)) more coins to unlock \(skin.name)." }
    }
    func claimAdBonus(for level: MazeLevel) {
        let previous = progress
        progress.claimAdBonus(level: level)
        if !save() { progress = previous; notice = "Your reward could not be saved. Please try again." }
    }
    func setHaptics(_ enabled: Bool) { progress.hapticsEnabled = enabled; save() }
    func setSound(_ enabled: Bool) { progress.soundEnabled = enabled; save() }
    func setDirectionButtons(_ enabled: Bool) { progress.directionButtonsEnabled = enabled; save() }
    func dismissTutorial() { progress.tutorialDismissed = true; save() }

    private func clearTransientState() {
        // Special-session results have no saved crown once their board is gone.
        // Cancel the actual native owner, not just its awaiting presentation task.
        for id in nonpersistentCompletionIDs { completionTasks[id]?.cancel() }
        runID = UUID(); inputID = UUID(); earnedPoints = 0; hint = nil; notice = nil
        completedOptimality = nil
        blockedDirection = nil
        isRewardPending = false; coinRewardRequestID = nil; rewardedRequestIDs.removeAll(); lastTick = uptimeProvider()
        if tracksPresentationReadiness { presentationReady = false }
        startCompletionVerification()
        refreshOptimalHintPreparation()
    }

    /// A celebration may use an available proof, but progression must never wait.
    func completedRunOptimalityIfReady(for completedRunID: UUID) -> MazeOptimality.Result? {
        guard completedRunID == runID, completedOptimality?.runID == completedRunID else { return nil }
        return completedOptimality?.result
    }

    /// Explicit proof consumers can await the store's work after completion.
    func completedRunOptimality(for completedRunID: UUID) async -> MazeOptimality.Result {
        guard completedRunID == runID, run.isComplete else { return .incomplete }
        startCompletionVerification()
        guard let verification = completionVerification, verification.runID == completedRunID else { return .undetermined }
        return await verification.task.value
    }

    private func startCompletionVerification() {
        guard run.isComplete, completionVerification?.runID != runID else { return }
        let completedRunID = runID
        let finishedRun = run
        let savesLevelProgress = !isDaily && !isDuel
        let stageIndex = isTimeRush ? timeRushSession?.stageIndex : nil
        let savedMinimum = savesLevelProgress ? savedMinimum(for: finishedRun) : nil
        let pending = savesLevelProgress
            ? pendingCompletions.first { $0.run == finishedRun && $0.stageIndex == stageIndex }
            : nil
        let completion = pending ?? PendingCompletion(id: completedRunID, run: finishedRun, stageIndex: stageIndex)
        if savesLevelProgress {
            progress.recordCompletedRun(finishedRun, stageIndex: stageIndex)
            if pending == nil { pendingCompletions.append(completion) }
            save()
        }
        if let savedMinimum {
            completedOptimality = (completedRunID, finishedRun.moves == savedMinimum ? .optimal : .notOptimal)
        }
        let result = launchCompletionVerification(completion, savesLevelProgress: savesLevelProgress,
                                                 savedMinimum: savedMinimum)
        bindCompletionResult(result, to: completedRunID)
    }

    private func savedMinimum(for run: MazeRun) -> Int? {
        if let minimum = MazePerfectMoveCatalog.minimumMoves(for: run.level) { return minimum }
        return progress.optimalMoves(for: run.level)
    }

    private func resumeCompletionVerifications() {
        var seen: Set<UUID> = []
        let previousCount = pendingCompletions.count
        pendingCompletions = pendingCompletions.filter {
            $0.run.isComplete && $0.run.moves >= 0 && seen.insert($0.id).inserted
                && ($0.run.level.mode != .timed || $0.stageIndex.map { (0..<5).contains($0) } == true)
                && ($0.run.level.mode != .endless || !(1...1_000).contains($0.run.level.number)
                    || MazePerfectMoveCatalog.minimumMoves(for: $0.run.level) != nil)
        }
        if pendingCompletions.count != previousCount { save() }
        for completion in pendingCompletions {
            let minimum = savedMinimum(for: completion.run)
            let result = launchCompletionVerification(completion, savesLevelProgress: true,
                                                     savedMinimum: minimum)
            // The currently restored completed board shares its persisted proof.
            // Starting a second request here would waste another uncapped solve.
            if !isDaily && !isDuel && run == completion.run,
               completion.stageIndex == (isTimeRush ? timeRushSession?.stageIndex : nil) {
                if let minimum {
                    completedOptimality = (runID, completion.run.moves == minimum ? .optimal : .notOptimal)
                }
                bindCompletionResult(result, to: runID)
            }
        }
    }

    private func bindCompletionResult(_ result: Task<MazeOptimality.Result, Never>, to completedRunID: UUID) {
        let task = Task { [weak self] in
            let value = await result.value
            if self?.runID == completedRunID { self?.completedOptimality = (completedRunID, value) }
            return value
        }
        completionVerification = (completedRunID, task)
    }

    private func launchCompletionVerification(
        _ completion: PendingCompletion, savesLevelProgress: Bool, savedMinimum: Int?
    ) -> Task<MazeOptimality.Result, Never> {
        if let existing = completionResults[completion.id] { return existing }
        let verifier = completionVerifier
        let verification = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return MazeOptimality.Result.undetermined }
            if let savedMinimum {
                return completion.run.moves == savedMinimum ? MazeOptimality.Result.optimal : .notOptimal
            }
            let result = await verifier(completion.run)
            return Task.isCancelled ? .undetermined : result
        }
        completionTasks[completion.id] = verification
        if !savesLevelProgress { nonpersistentCompletionIDs.insert(completion.id) }
        let task = Task { [weak self] in
            let result = await verification.value
            if let self {
                self.completionTasks.removeValue(forKey: completion.id)
                self.completionResults.removeValue(forKey: completion.id)
                self.nonpersistentCompletionIDs.remove(completion.id)
                if savesLevelProgress {
                    // Use the captured board and stage even if another level is now open.
                    self.progress.recordCompletedRun(completion.run, optimality: result, stageIndex: completion.stageIndex)
                    let proved = result == .optimal || result == .notOptimal
                    if proved { self.pendingCompletions.removeAll { $0.id == completion.id } }
                    if !self.save(), proved {
                        // Keep retry evidence if this write failed; the last
                        // persisted snapshot already contains the pending run.
                        self.pendingCompletions.append(completion)
                    }
                }
            }
            return result
        }
        completionResults[completion.id] = task
        return task
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
                   saved.moves == 0, saved.position == session.currentLevel.start,
                   saved.painted == [session.currentLevel.start], saved.extraMovesGranted == 0 {
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
    @discardableResult
    private func save() -> Bool {
        cacheCurrentRun()
        let snapshot = GameSnapshot(progress: progress, runs: savedRuns, clocks: savedClocks, mode: mode,
                                    dailyRun: savedDailyRun, dailyID: dailyChallenge.id, dailyActive: isDaily, themeID: theme.rawValue,
                                    timeRushSession: timeRushSession,
                                    pendingCompletions: pendingCompletions.isEmpty ? nil : pendingCompletions)
        do {
            let data = try snapshotEncoder.encode(snapshot)
            try progressPersistence.persist(progress)
            defaults.set(data, forKey: "prism.snapshot.v2")
            return true
        } catch {
            return false
        }
    }
}
