import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var duel: DuelService
    @EnvironmentObject private var purchases: PurchaseService
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = "play"
    @State private var settingsOpen = false
    @State private var readyRunID: UUID?
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $tab) {
            navigationPage("Prism Roll") {
                PlayView(isActive: playSceneActive) { ready, runID in
                    guard runID == store.runID else { return }
                    if ready { readyRunID = runID }
                    else if readyRunID == runID { readyRunID = nil }
                }
            }
                .tabItem { Label("Play", systemImage: "square.grid.3x3.fill").accessibilityIdentifier("tab_play") }
                .tag("play")
            navigationPage("Challenges") { ChallengesView { tab = "play" } }
                .tabItem { Label("Challenges", systemImage: "trophy.fill").accessibilityIdentifier("tab_challenges") }
                .tag("challenges")
            navigationPage("Collection") { CollectionView() }
                .tabItem { Label("Collection", systemImage: "circle.hexagongrid.fill").accessibilityIdentifier("tab_collection") }
                .tag("collection")
            navigationPage("Journey") { JourneyView { tab = "play" } }
                .tabItem { Label("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath").accessibilityIdentifier("tab_journey") }
                .tag("journey")
        }
        .tint(Palette.violet)
        .gameplaySwipes(
            enabled: tab == "play" && readyRunID == store.runID && store.acceptsGameplayInput
                && scenePhase == .active && !settingsOpen && !duel.isMatching
                && !ads.isPresenting && !ads.isPrivacyFormPresenting && store.notice == nil
                && !store.hasEnded && !store.isRewardPending && !(store.isDuel && duel.didWin != nil),
            sessionID: store.inputID,
            onSwipe: { direction, inputID in store.move(direction, for: inputID) }
        )
        .sheet(isPresented: $settingsOpen) { SettingsView() }
        .alert("Prism Roll", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("Got it", role: .cancel) { store.notice = nil }
        } message: { Text(store.notice ?? "") }
        .onReceive(timer) { _ in store.tick() }
        .onAppear {
            store.setActivity(active: scenePhase == .active, visible: tab == "play", modal: settingsOpen)
            prepareAds()
            duel.onStart = { seed, id in
                guard scenePhase == .active, !ads.isPresenting, !ads.isPrivacyFormPresenting else {
                    duel.cancel()
                    return
                }
                settingsOpen = false
                store.notice = nil
                store.openDuel(seed: seed, id: id)
                tab = "play"
                duel.sendProgress(painted: store.run.painted.count, total: store.run.level.openCells.count, moves: 0)
            }
        }
        .task { await purchases.load() }
        .onChange(of: scenePhase) { _, phase in
            store.setActivity(active: phase == .active)
            if phase == .active { store.refreshDaily(); prepareAds() }
            else if phase == .background, duel.isMatching || duel.isPlaying || store.isDuel {
                duel.cancel()
                if store.isDuel { store.endSpecialSession() }
            }
        }
        .onChange(of: tab) { _, newTab in
            store.setActivity(visible: newTab == "play")
            if newTab == "challenges" { store.refreshDaily() }
            if newTab != "play", store.isDuel { duel.cancel(); store.endSpecialSession() }
        }
        .onChange(of: duel.matchID) { _, id in
            if id == nil, store.isDuel {
                let message = duel.status
                store.endSpecialSession()
                store.notice = message
            }
        }
        .onChange(of: duel.isMatching) { _, _ in syncModalState() }
        .onChange(of: settingsOpen) { _, _ in syncModalState() }
        .onChange(of: ads.isPresenting) { _, _ in syncModalState() }
        .onChange(of: ads.isPrivacyFormPresenting) { _, _ in syncModalState() }
        .onChange(of: store.notice) { _, _ in syncModalState() }
        .onChange(of: purchases.removesAds) { _, removed in ads.interstitialsDisabled = removed }
        .onChange(of: store.run.moves) { _, _ in
            if store.isDuel {
                duel.sendProgress(painted: store.run.painted.count, total: store.run.level.openCells.count, moves: store.run.moves)
                if store.run.isComplete { duel.submitCompletion() }
            }
        }
    }

    private var playSceneActive: Bool {
        tab == "play" && scenePhase == .active && !settingsOpen && !duel.isMatching
            && !ads.isPresenting && !ads.isPrivacyFormPresenting && store.notice == nil
    }

    private func syncModalState() { store.setActivity(modal: settingsOpen || duel.isMatching || ads.isPresenting || ads.isPrivacyFormPresenting || store.notice != nil) }
    private func prepareAds() {
        ads.interstitialsDisabled = purchases.removesAds
        ads.prepare()
    }
    private func navigationPage<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
                    ToolbarItem(placement: .topBarTrailing) {
                        CoinBadge(amount: store.progress.points)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(store.progress.points) coins")
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
