import Foundation

/// Calendar-independent day identity, with the supplied calendar's local time zone.
struct DailyCalendar {
    static func normalized(_ calendar: Calendar) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = calendar.timeZone
        return result
    }

    static func dayID(for date: Date, calendar: Calendar) -> String {
        let local = normalized(calendar)
        let components = local.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1, components.month ?? 1, components.day ?? 1)
    }

    static func dayDistance(from dayID: String, to date: Date, calendar: Calendar) -> Int? {
        let components = dayID.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        let local = normalized(calendar)
        guard let previous = local.date(from: DateComponents(
            year: components[0], month: components[1], day: components[2]
        )) else { return nil }
        return local.dateComponents([.day], from: previous, to: local.startOfDay(for: date)).day
    }
}
