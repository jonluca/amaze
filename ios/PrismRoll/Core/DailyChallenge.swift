import Foundation

struct DailyChallenge: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let date: Date
    let level: MazeLevel
    var reward: Int { 100 }

    private init(id: String, date: Date, level: MazeLevel) {
        self.id = id
        self.date = date
        self.level = level
    }

    static func generate(for date: Date, calendar: Calendar = .current) -> DailyChallenge {
        let day = DailyCalendar.dayID(for: date, calendar: calendar)
        // FNV-1a avoids Swift Hasher's per-process randomization.
        let seed = day.utf8.reduce(UInt64(0xCBF29CE484222325)) { ($0 ^ UInt64($1)) &* 0x100000001B3 }
        let number = max(1, Int(seed & UInt64(Int.max)))
        // A date hash identifies the board; it is not a player progression level.
        // Keep the daily at a substantial 12×12 without jumping to the final tier.
        let level = MazeLevel.generate(number: number, mode: .challenge, difficultyNumber: 22)
        return DailyChallenge(
            id: day, date: DailyCalendar.normalized(calendar).startOfDay(for: date), level: level
        )
    }
}
