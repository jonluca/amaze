import Foundation

struct GameCenterReportPersistence {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "game-center-report-ledger-v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> GameCenterReportLedger {
        guard let data = defaults.data(forKey: key),
              let ledger = try? JSONDecoder().decode(GameCenterReportLedger.self, from: data) else {
            return GameCenterReportLedger()
        }
        return ledger
    }

    func save(_ ledger: GameCenterReportLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: key)
    }
}
