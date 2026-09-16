enum GameCenterActivityDestination: String, CaseIterable, Identifiable, Sendable {
    case classic
    case timeRush = "time_rush"
    case daily

    var id: String { "com.jonluca.prismroll.activity.\(rawValue)" }

    init?(identifier: String) {
        guard let destination = Self.allCases.first(where: { $0.id == identifier }) else { return nil }
        self = destination
    }
}
