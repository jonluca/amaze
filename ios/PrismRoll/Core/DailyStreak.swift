import Foundation

struct DailyStreak: Codable, Equatable, Sendable {
    private(set) var count = 0
    private(set) var lastDayID: String?
    private(set) var lastClaimedAt: Date?

    func currentCount(at date: Date, calendar: Calendar) -> Int {
        guard let lastDayID,
              let distance = DailyCalendar.dayDistance(from: lastDayID, to: date, calendar: calendar),
              distance == 0 || distance == 1 else { return 0 }
        return count
    }

    func nextCount(at date: Date, calendar: Calendar) -> Int? {
        if let lastClaimedAt, date <= lastClaimedAt { return nil }
        guard let lastDayID else { return 1 }
        guard let distance = DailyCalendar.dayDistance(from: lastDayID, to: date, calendar: calendar),
              distance > 0 else { return nil }
        return distance == 1 ? count + 1 : 1
    }

    @discardableResult
    mutating func claim(at date: Date, calendar: Calendar) -> Int? {
        guard let next = nextCount(at: date, calendar: calendar) else { return nil }
        count = next
        lastDayID = DailyCalendar.dayID(for: date, calendar: calendar)
        lastClaimedAt = date
        return next
    }
}
