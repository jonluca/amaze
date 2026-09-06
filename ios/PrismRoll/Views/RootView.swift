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
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 9).padding(.bottom, 16)
            Group {
                switch tab {
                case "collection": CollectionView()
                case "challenges": ChallengesView { tab = "play" }
                case "journey": JourneyView { tab = "play" }
                default: PlayView()
                }
            }.frame(maxWidth: 720, maxHeight: .infinity)
            navigation
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GameBackdrop())
        .foregroundStyle(Palette.ink)
        .buttonStyle(PressStyle())
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

    private func syncModalState() { store.setActivity(modal: settingsOpen || duel.isMatching || ads.isPresenting || ads.isPrivacyFormPresenting || store.notice != nil) }
    private func prepareAds() {
        ads.interstitialsDisabled = purchases.removesAds
        ads.prepare()
    }
    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 29, weight: .bold)).foregroundStyle(Palette.violet)
                .shadow(color: Palette.violet.opacity(0.4), radius: 10).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: -1) {
                Text("PRISM").font(.system(size: 14, weight: .black, design: .rounded)).tracking(2.3)
                Text("ROLL").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(5.1).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 8)
            Button { tab = "challenges" } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Palette.accent)
                    Text("\(store.currentStreak)").font(.system(size: 13, weight: .bold, design: .rounded))
                }.padding(10).background(Palette.paper, in: Capsule())
            }.accessibilityLabel("Daily streak, \(store.currentStreak) days")
            CoinBadge(amount: store.progress.points)
                .accessibilityElement(children: .ignore).accessibilityLabel("\(store.progress.points) coins")
                .accessibilityIdentifier("pointsBalance")
            Button { settingsOpen = true } label: {
                Image(systemName: "gearshape").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.secondary).frame(width: 34, height: 42)
            }.accessibilityLabel("Settings")
        }.frame(maxWidth: 672)
    }
    private var navigation: some View {
        HStack(spacing: 4) {
            navItem("play", title: "Play", icon: "square.grid.3x3.fill")
            navItem("challenges", title: "Challenges", icon: "trophy.fill")
            navItem("collection", title: "Collection", icon: "circle.hexagongrid.fill")
            navItem("journey", title: "Journey", icon: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .padding(6).background(Palette.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line, lineWidth: 1))
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 7).frame(maxWidth: 550)
    }
    private func navItem(_ id: String, title: String, icon: String) -> some View {
        Button { tab = id } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .bold, design: .rounded))
            }.frame(maxWidth: .infinity).frame(height: 53)
                .foregroundStyle(tab == id ? Palette.violet : Palette.secondary)
                .background(tab == id ? Palette.violet.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 18))
        }.accessibilityIdentifier("tab_\(id)").accessibilityAddTraits(tab == id ? .isSelected : [])
    }
}
