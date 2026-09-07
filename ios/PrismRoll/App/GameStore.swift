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
    @Published private(set) var clock: TimedRunState?
    @Published private(set) var dailyChallenge: DailyChallenge
    @Published private(set) var isDaily = false
    @Published private(set) var duelID: String?
    @Published var theme: BoardTheme { didSet { save() } }
    @Published var hint: MoveDirection?
    @Published var notice: String?
    @Published private(set) var earnedPoints = 0
    @Published private(set) var isRewardPending = false
    private let defaults: UserDefaults
    private let dateProvider: () -> Date
    private let uptimeProvider: () -> TimeInterval
    private var savedRuns: [String: MazeRun]
    private var savedClocks: [String: TimedRunState]
    private var savedDailyRun: MazeRun?
    private var lastTick: TimeInterval?
    private var appActive = true
    private var playVisible = true
    private var modalOpen = false
    private var rewardedRequestIDs: Set<UUID> = []
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
        let loadedProgress = snapshot?.progress ?? defaults.data(forKey: "prism.progress").flatMap {
            try? decoder.decode(ProgressData.self, from: $0)
        } ?? ProgressData()
        let loadedRuns = snapshot?.runs ?? defaults.data(forKey: "prism.runs").flatMap {
            try? decoder.decode([String: MazeRun].self, from: $0)
        } ?? [:]
        let loadedMode = snapshot?.mode ?? GameMode(rawValue: defaults.string(forKey: "prism.mode") ?? "endless") ?? .endless
        let daily = DailyChallenge.generate(for: now())
        let resumeDaily = snapshot?.dailyActive == true && snapshot?.dailyID == daily.id
        progress = loadedProgress
        savedRuns = loadedRuns
        savedClocks = snapshot?.clocks ?? [:]
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
        clock = resumeDaily ? nil : snapshot?.clocks[loadedMode.rawValue] ?? loadedRun.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        lastTick = uptime()
    }

    var skin: BallSkin { BallSkin.catalog.first { $0.id == progress.selectedSkinID } ?? BallSkin.catalog[0] }
    var fraction: Double { Double(run.painted.count) / Double(max(run.level.openCells.count, 1)) }
    var isDuel: Bool { duelID != nil }
    var timeExpired: Bool { clock.map { $0.hasStarted && $0.remainingSeconds <= 0 } ?? false }
    var isFailed: Bool { !run.isComplete && (run.isFailed || timeExpired) }
    var hasEnded: Bool { run.isComplete || isFailed }
    var bonusClaimed: Bool { progress.hasClaimedAdBonus(level: run.level) }
    var canClaimAdBonus: Bool { !isDaily && !isDuel && run.isComplete && progress.hasCompleted(run.level) && !bonusClaimed }
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
    var clockRunning: Bool { appActive && playVisible && !modalOpen && !isRewardPending && !hasEnded && clock?.hasStarted == true }
    var acceptsGameplayInput: Bool { appActive && playVisible && !modalOpen && notice == nil && !hasEnded && !isRewardPending }

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
        guard !path.isEmpty else { return }
        moveEvents.send(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                     painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        clock?.hasStarted = true
        lastTick = uptimeProvider()
        hint = nil
        if !isDaily && !isDuel { progress.awardCollectedCoins(for: run) }
        if progress.hapticsEnabled { feedback.impactOccurred(intensity: 0.7) }
        if progress.soundEnabled { AudioServicesPlaySystemSound(1104) }
        if run.isComplete {
            earnedPoints = isDuel ? 0 : isDaily ? progress.completeDailyChallenge(dailyChallenge, at: dateProvider()) : progress.completeLevel(run.level)
            if progress.hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        save()
    }

    func switchMode(_ next: GameMode) {
        guard next != mode || isDaily || isDuel else { return }
        tick(); cacheCurrentRun()
        isDaily = false; duelID = nil; mode = next
        run = savedRuns[next.rawValue] ?? MazeRun(level: .generate(number: currentUnlockedLevel, mode: next))
        clock = savedClocks[next.rawValue] ?? run.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        clearTransientState(); save()
    }

    func replay() {
        run.reset()
        clock = run.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        clearTransientState(); save()
    }

    func nextLevel() {
        if isDaily || isDuel { endSpecialSession(); return }
        let following = run.level.number == Int.max ? Int.max : run.level.number + 1
        run = MazeRun(level: .generate(number: max(following, currentUnlockedLevel), mode: mode))
        clock = run.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        clearTransientState(); save()
    }

    func openLevel(_ number: Int) {
        guard number >= 1, number <= currentUnlockedLevel else { return }
        isDaily = false; duelID = nil
        run = MazeRun(level: .generate(number: number, mode: mode))
        clock = run.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        clearTransientState(); save()
    }

    func openDaily() {
        tick(); cacheCurrentRun()
        isDaily = true; duelID = nil
        run = savedDailyRun ?? MazeRun(level: dailyChallenge.level)
        clock = nil
        clearTransientState(); save()
    }

    func openDuel(seed: Int, id: String) {
        tick(); cacheCurrentRun()
        isDaily = false; duelID = id
        run = MazeRun(level: .generate(number: seed, mode: .endless))
        clock = nil
        clearTransientState()
    }

    func endSpecialSession() {
        cacheCurrentRun()
        isDaily = false; duelID = nil
        run = savedRuns[mode.rawValue] ?? MazeRun(level: .generate(number: currentUnlockedLevel, mode: mode))
        clock = savedClocks[mode.rawValue] ?? run.level.timeLimit.map { TimedRunState(remainingSeconds: $0) }
        clearTransientState(); save()
    }

    func showHint() {
        guard !hasEnded, !isDuel else { return }
        hint = run.hintDirection
    }

    func rewardRequest(_ kind: GameplayReward) -> GameplayRewardRequest? {
        let originalRun = runID
        tick()
        guard originalRun == runID, !isDuel else { return nil }
        switch kind {
        case .hint: guard !hasEnded else { return nil }
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
            notice = "\(skin.name) equipped"
            if progress.hapticsEnabled { feedback.impactOccurred() }
        } else { notice = "Earn \(max(0, skin.price - progress.points)) more coins to unlock \(skin.name)." }
        save()
    }
    func claimAdBonus(for level: MazeLevel) { progress.claimAdBonus(level: level); save() }
    func setHaptics(_ enabled: Bool) { progress.hapticsEnabled = enabled; save() }
    func setSound(_ enabled: Bool) { progress.soundEnabled = enabled; save() }

    private func clearTransientState() {
        runID = UUID(); inputID = UUID(); earnedPoints = 0; hint = nil; notice = nil
        isRewardPending = false; rewardedRequestIDs.removeAll(); lastTick = uptimeProvider()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--short-timer"), clock != nil { clock = TimedRunState(remainingSeconds: 2) }
#endif
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
                                    dailyRun: savedDailyRun, dailyID: dailyChallenge.id, dailyActive: isDaily, themeID: theme.rawValue)
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: "prism.snapshot.v2") }
    }
}
