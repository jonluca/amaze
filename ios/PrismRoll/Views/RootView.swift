import SwiftUI
import Combine
import StoreKit

struct RootView: View {
    @ObservedObject private var analytics = AnalyticsService.shared
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var duel: DuelService
    @EnvironmentObject private var gameCenter: GameCenterService
    @EnvironmentObject private var gameActivities: GameCenterActivityCoordinator
    @EnvironmentObject private var purchases: PurchaseService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.requestReview) private var requestReview
    @State private var reviewPrompts = ReviewPromptStore()
    @State private var sharedChallenge: SharedChallenge?
    @State private var pendingSharedChallenge: SharedChallenge?
    @State private var tab = "play"
    @State private var settingsOpen = false
    @State private var gameCenterOpen = false
    @State private var gameCenterPresented = false
    @State private var coinShopOpen = false
    @State private var settingsPresented = false
    @State private var coinShopPresented = false
    @State private var challengeShareOpen = false
    @State private var analyticsChoicePresented = false
    @State private var restartPromptOpen = false
    @State private var restartRunID: UUID?
    @State private var readyRunID: UUID?
    @State private var completedRunID: UUID?
    @State private var advancingRunID: UUID?
    @State private var adCheckedRunID: UUID?
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        contentWithRunChanges
    }

    private var tabsWithGameplayInput: some View {
        TabView(selection: $tab) {
            navigationPage("Prism Roll") {
                PlayView(isActive: playSceneActive, onRestart: requestRestart,
                         onCompletionReady: completedLevel) { ready, runID in
                    guard runID == store.runID else { return }
                    store.setPresentationReady(ready, for: runID)
                    if ready { readyRunID = runID }
                    else if readyRunID == runID { readyRunID = nil }
                }
                .alert(store.isTimeRush ? "Restart this round?" : "Restart this level?", isPresented: $restartPromptOpen) {
                    Button(store.isTimeRush ? "Restart round" : "Restart level", role: .destructive) {
                        guard restartRunID == store.runID else { return }
                        store.replay()
                    }
                    .accessibilityIdentifier("confirmRestart")
                    Button("Keep playing", role: .cancel) {}
                        .accessibilityIdentifier("cancelRestart")
                } message: {
                    Text(store.isTimeRush
                         ? "Restarting returns to maze 1 of \(store.timeRushMazeCount) and resets the round timer, including extra time. Earned coins are kept."
                         : "Restarting clears this run's paint and extra time or moves. Earned coins are kept.")
                }
            }
                .tabItem { Label("Play", systemImage: "square.grid.3x3.fill").accessibilityIdentifier("tab_play") }
                .tag("play")
            navigationPage("Challenges") {
                ChallengesView(onSharePresentationChanged: setChallengeSharing, onShowGameCenter: openGameCenter) { tab = "play" }
                    .navigationDestination(isPresented: $gameCenterOpen) { GameCenterView() }
            }
                .tabItem { Label("Challenges", systemImage: "trophy.fill").accessibilityIdentifier("tab_challenges") }
                .tag("challenges")
            navigationPage("Collection") { CollectionView { coinShopOpen = true } }
                .tabItem { Label("Collection", systemImage: "circle.hexagongrid.fill").accessibilityIdentifier("tab_collection") }
                .tag("collection")
            navigationPage("Levels") { JourneyView(onSharePresentationChanged: setChallengeSharing) { tab = "play" } }
                .tabItem { Label("Levels", systemImage: "square.grid.2x2.fill").accessibilityIdentifier("tab_journey") }
                .tag("journey")
        }
        .tint(Palette.violet)
        .gameplaySwipes(
            enabled: tab == "play" && readyRunID == store.runID && store.acceptsGameplayInput
                && sharedChallenge == nil && !gameCenterIsPresenting
                && scenePhase == .active && !settingsOpen && !coinShopOpen && !restartPromptOpen && !duel.isMatching
                && !ads.isPresenting && !ads.isPrivacyFormPresenting && store.notice == nil
                && !store.hasEnded && !store.isRewardPending && !(store.isDuel && duel.didWin != nil),
            sessionID: store.inputID,
            onSwipe: { direction, inputID in store.move(direction, for: inputID) }
        )
    }

    private var contentWithPresentations: some View {
        tabsWithGameplayInput
        .sheet(isPresented: $settingsOpen, onDismiss: { settingsPresented = false; syncModalState() }) {
            SettingsView(onShowGameCenter: openGameCenter).onAppear { settingsPresented = true }
        }
        .sheet(isPresented: $coinShopOpen, onDismiss: { coinShopPresented = false; syncModalState() }) {
            CoinShopView().onAppear { coinShopPresented = true }
        }
        .fullScreenCover(item: $gameCenter.presentation, onDismiss: {
            gameCenterPresented = false
            gameCenter.presentationDidDismiss()
            syncModalState()
        }) { presentation in
            GameCenterControllerView(presentation: presentation)
                .ignoresSafeArea()
                .onAppear { gameCenterPresented = true; syncModalState() }
        }
        .fullScreenCover(item: $sharedChallenge, onDismiss: { syncModalState(); prepareAds() }) { challenge in
            SharedChallengeView(challenge: challenge, skin: store.skin, theme: store.theme,
                                hapticsEnabled: store.progress.hapticsEnabled,
                                soundEnabled: store.progress.soundEnabled,
                                directionButtonsEnabled: store.progress.directionButtonsEnabled)
                .id(challenge.id)
        }
        .onOpenURL(perform: receiveChallenge)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { receiveChallenge(url) }
        }
        .sheet(isPresented: analyticsChoiceBinding, onDismiss: {
            analyticsChoicePresented = false
            syncModalState()
            prepareAds()
        }) {
            AnalyticsConsentView().onAppear {
                analyticsChoicePresented = true
                syncModalState()
            }
        }
        .alert("Prism Roll", isPresented: noticeBinding) {
            Button("Got it", role: .cancel) { store.notice = nil }
        } message: { Text(store.notice ?? "") }
    }

    private var contentWithLifecycle: some View {
        contentWithPresentations
        .onReceive(timer) { _ in store.tick() }
        .onAppear {
            reviewPrompts.recordEngagement()
            analytics.screen(tab)
            store.setPresentationReady(readyRunID == store.runID, for: store.runID)
            store.setActivity(active: scenePhase == .active, visible: tab == "play")
            gameCenter.observe(store.gameCenterProgress)
            gameActivities.setAuthenticated(gameCenter.authenticated)
            gameActivities.start()
            syncModalState()
            gameCenter.start()
            prepareAds()
            duel.onStart = { seed, id in
                guard scenePhase == .active, !ads.isPresenting, !ads.isPrivacyFormPresenting else {
                    duel.cancel()
                    return
                }
                settingsOpen = false
                coinShopOpen = false
                store.notice = nil
                store.openDuel(seed: seed, id: id)
                tab = "play"
                duel.sendProgress(painted: store.run.painted.count, total: store.run.level.openCells.count, moves: 0)
            }
        }
        .task {
            purchases.configureCoinDelivery { try store.deliverCoinPurchase($0) }
            await purchases.load()
        }
        .onChange(of: scenePhase) { _, phase in
            store.setActivity(active: phase == .active)
            if phase == .active {
                gameCenter.refresh()
                reviewPrompts.recordEngagement()
                syncModalState()
                store.refreshDaily()
                prepareAds()
                Task { await purchases.recoverUnfinishedPurchases() }
            }
            else if phase == .background, duel.isMatching || duel.isPlaying || store.isDuel {
                duel.cancel()
                if store.isDuel { store.endSpecialSession() }
            }
            updateGameCenterPresentationGate()
        }
        .onChange(of: tab) { _, newTab in
            analytics.screen(newTab == "journey" ? "levels" : newTab)
            store.setActivity(visible: newTab == "play")
            if newTab == "challenges" { store.refreshDaily() }
            if newTab != "play", store.isDuel { duel.cancel(); store.endSpecialSession() }
            if newTab != "play" { requestReviewAtRest() }
            syncModalState()
        }
        .onChange(of: duel.matchID) { _, id in
            if id == nil, store.isDuel {
                let message = duel.status
                store.endSpecialSession()
                store.notice = message
            }
        }
    }

    private var contentWithModalChanges: some View {
        contentWithLifecycle
        .onChange(of: duel.isMatching) { _, _ in syncModalState() }
        .onChange(of: gameCenter.presentation?.id) { _, _ in syncModalState() }
        .onChange(of: gameCenter.authenticated) { _, authenticated in
            gameActivities.setAuthenticated(authenticated)
        }
        .onChange(of: store.gameCenterProgress) { _, progress in gameCenter.observe(progress) }
        .onChange(of: gameActivities.pendingDestination) { _, _ in syncModalState() }
        .onChange(of: store.mode) { _, _ in syncModalState() }
        .onChange(of: store.isDaily) { _, _ in syncModalState() }
        .onChange(of: store.isFailed) { _, failed in
            if failed { gameActivities.finish() }
        }
        .onChange(of: settingsOpen) { _, open in
            syncModalState()
            analytics.screen(open ? "settings" : (tab == "journey" ? "levels" : tab))
        }
        .onChange(of: coinShopOpen) { _, open in
            syncModalState()
            analytics.screen(open ? "coin_shop" : (tab == "journey" ? "levels" : tab))
        }
        .onChange(of: analytics.hasMadeChoice) { _, _ in syncModalState() }
        .onChange(of: restartPromptOpen) { _, _ in syncModalState() }
        .onChange(of: sharedChallenge) { _, _ in
            syncModalState()
            analytics.screen(sharedChallenge == nil ? (tab == "journey" ? "levels" : tab) : "shared_challenge")
        }
        .onChange(of: store.isRewardPending) { _, _ in syncModalState() }
    }

    private var contentWithRunChanges: some View {
        contentWithModalChanges
        .onChange(of: playSceneActive) { _, active in
            gameActivities.setPlaying(active)
            if active { advanceCompletedLevelIfReady() }
        }
        .onChange(of: readyRunID) { _, _ in advanceCompletedLevelIfReady() }
        .onChange(of: store.runID) { _, _ in
            restartPromptOpen = false
            restartRunID = nil
            completedRunID = nil
            advancingRunID = nil
            adCheckedRunID = nil
            updateGameCenterPresentationGate()
        }
        .onChange(of: ads.isPresenting) { _, _ in syncModalState() }
        .onChange(of: ads.isPrivacyFormPresenting) { _, _ in syncModalState() }
        .onChange(of: ads.isUpdatingConsent) { _, _ in syncModalState() }
        .onChange(of: store.notice) { _, _ in syncModalState() }
        .onChange(of: store.progress.soundEnabled) { _, enabled in ads.setSoundEnabled(enabled) }
        .onChange(of: purchases.removesAds) { _, removed in ads.interstitialsDisabled = removed }
        .onChange(of: store.run.moves) { _, _ in
            updateGameCenterPresentationGate()
            if store.isDuel {
                duel.sendProgress(painted: store.run.painted.count, total: store.run.level.openCells.count, moves: store.run.moves)
                if store.run.isComplete { duel.submitCompletion() }
            }
        }
    }

    private var analyticsChoiceBinding: Binding<Bool> {
        Binding<Bool>(get: { needsAnalyticsChoice }, set: { _ in })
    }

    private var noticeBinding: Binding<Bool> {
        Binding<Bool>(
            get: { store.notice != nil },
            set: { isPresented in
                if !isPresented { store.notice = nil }
            }
        )
    }

    private var playSceneActive: Bool {
        tab == "play" && scenePhase == .active && !settingsOpen && !coinShopOpen && !restartPromptOpen && !duel.isMatching
            && sharedChallenge == nil && !gameCenterIsPresenting
            && !ads.isPresenting && !ads.isPrivacyFormPresenting && store.notice == nil && !needsAnalyticsChoice && !analyticsChoicePresented
    }

    private var needsAnalyticsChoice: Bool {
        analytics.isAvailable && !analytics.hasMadeChoice && !isUITesting
    }

    private var gameCenterIsPresenting: Bool {
        gameCenter.presentation != nil || gameCenterPresented
    }

    private var isUITesting: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitesting")
#else
        false
#endif
    }

    private func requestRestart() {
        if store.run.moves > 0 || store.run.extraMovesGranted > 0
            || (store.isTimeRush && store.timeRushMazeNumber > 1)
            || (store.clock?.remainingSeconds ?? 0) > (store.run.level.timeLimit ?? 0) {
            restartRunID = store.runID
            restartPromptOpen = true
        } else {
            store.replay()
        }
    }

    private func completedLevel(_ runID: UUID) {
        guard store.runID == runID, store.run.isComplete, !store.isDuel else { return }
        if store.hasEnded { gameActivities.finish() }
        completedRunID = runID
        advanceCompletedLevelIfReady()
    }

    private func advanceCompletedLevelIfReady() {
        guard let runID = completedRunID, runID == store.runID,
              store.run.isComplete, !store.isDuel, playSceneActive,
              readyRunID == runID, !store.isRewardPending, advancingRunID == nil else { return }
        // Keep a settled result pending through menus/backgrounding. Intermediate
        // mazes share the clock and never trigger a between-round advertisement.
        if store.advanceTimeRushMaze(after: runID) { return }
        guard store.hasEnded else { return }
        if store.isDaily || adCheckedRunID == runID {
            store.advanceCompletedLevel(for: runID)
            return
        }
        advancingRunID = runID
        adCheckedRunID = runID
        ads.presentInterstitial {
            guard advancingRunID == runID else { return }
            advancingRunID = nil
            syncModalState()
            advanceCompletedLevelIfReady()
        }
    }

    private func syncModalState() {
        presentPendingChallengeIfReady()
        launchPendingGameActivityIfReady()
        updateGameCenterPresentationGate()
        store.setActivity(modal: settingsOpen || coinShopOpen || restartPromptOpen || duel.isMatching
                          || ads.isPresenting || ads.isPrivacyFormPresenting || store.notice != nil
                          || needsAnalyticsChoice || analyticsChoicePresented || sharedChallenge != nil
                          || settingsPresented || coinShopPresented || challengeShareOpen || gameCenterIsPresenting)
        gameActivities.setPlaying(playSceneActive)
        gameActivities.setContext(mode: store.mode, isDaily: store.isDaily, isDuel: store.isDuel)
    }

    private func openGameCenter() {
        settingsOpen = false
        tab = "challenges"
        gameCenterOpen = true
    }

    private var canPresentGameCenter: Bool {
        scenePhase == .active && !settingsOpen && !coinShopOpen && !restartPromptOpen
            && !settingsPresented && !coinShopPresented && !challengeShareOpen
            && !duel.isMatching && !store.isDuel && !store.isRewardPending
            && !ads.isPresenting && !ads.isPrivacyFormPresenting && !ads.isUpdatingConsent
            && store.notice == nil && !needsAnalyticsChoice && !analyticsChoicePresented
            && sharedChallenge == nil && !gameCenterIsPresenting
    }

    private func updateGameCenterPresentationGate() {
        // A delayed sign-in response waits until the player leaves an active maze.
        gameCenter.setPresentationAllowed(canPresentGameCenter
            && (tab != "play" || store.run.moves == 0 || store.hasEnded))
    }

    private func launchPendingGameActivityIfReady() {
        guard let destination = gameActivities.pendingDestination, canPresentGameCenter else { return }
        store.openGameCenterActivity(destination)
        gameCenterOpen = false
        tab = "play"
        gameActivities.didLaunchPendingActivity()
    }

    private func setChallengeSharing(_ open: Bool) {
        challengeShareOpen = open
        syncModalState()
    }

    private func receiveChallenge(_ url: URL) {
        do {
            let challenge = try ChallengeLink.decode(url)
            if sharedChallenge != nil { sharedChallenge = challenge }
            else { pendingSharedChallenge = challenge }
            syncModalState()
        } catch {
            store.notice = "This challenge link is invalid or needs a newer version of Prism Roll."
        }
    }

    private func presentPendingChallengeIfReady() {
        guard let pending = pendingSharedChallenge, sharedChallenge == nil, scenePhase == .active,
              !settingsOpen, !coinShopOpen, !restartPromptOpen, !duel.isMatching, !store.isDuel,
              !settingsPresented, !coinShopPresented, !challengeShareOpen, !gameCenterIsPresenting,
              !ads.isPresenting, !ads.isPrivacyFormPresenting, !ads.isUpdatingConsent, !store.isRewardPending,
              store.notice == nil, !needsAnalyticsChoice, !analyticsChoicePresented else { return }
        pendingSharedChallenge = nil
        sharedChallenge = pending
    }

    /// Request at a player-selected pause after sustained progress, never mid-maze.
    private func requestReviewAtRest() {
        guard scenePhase == .active, !settingsOpen, !coinShopOpen, sharedChallenge == nil,
              !settingsPresented, !coinShopPresented, !challengeShareOpen, !gameCenterIsPresenting, !gameCenterOpen,
              !ads.isPresenting, !ads.isPrivacyFormPresenting, !ads.isUpdatingConsent, !duel.isMatching,
              !needsAnalyticsChoice, !analyticsChoicePresented, store.notice == nil,
              !isUITesting,
              reviewPrompts.consumeRequest(completedLevels: store.progress.completedLevels) else { return }
        analytics.record("review_prompt_requested", parameters: [:])
        requestReview()
    }
    private func prepareAds() {
        guard !needsAnalyticsChoice, !analyticsChoicePresented, sharedChallenge == nil, !gameCenterIsPresenting else { return }
        ads.setSoundEnabled(store.progress.soundEnabled)
        ads.interstitialsDisabled = purchases.removesAds
        ads.prepare()
    }
    private func navigationPage<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !dynamicTypeSize.isAccessibilitySize {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { tab = "challenges" } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "flame.fill")
                                    Text("\(store.currentStreak)").monospacedDigit()
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Daily streak, \(store.currentStreak) days")
                            }
                            .accessibilityLabel("Daily streak, \(store.currentStreak) days")
                            .accessibilityIdentifier("dailyStreak")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { coinShopOpen = true } label: {
                            CoinBadge(amount: store.progress.points, compactDisplay: true)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }
                        .accessibilityLabel("\(store.progress.points) coins")
                        .accessibilityHint("Opens the coin shop")
                        .accessibilityIdentifier("pointsBalance")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { settingsOpen = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
        }
    }
}
