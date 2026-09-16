import Foundation

/// Eligibility concerns engagement only, never a predicted rating or sentiment.
struct ReviewPromptPolicy: Codable, Equatable {
    private(set) var engagedDays = 0
    private(set) var lastEngagedDay: Date?
    private(set) var requestedAt: [Date] = []
    private(set) var completionsAtLastRequest = 0

    mutating func recordEngagement(at date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        guard lastEngagedDay.map({ day > $0 }) ?? true else { return }
        engagedDays = min(365, engagedDays + 1)
        lastEngagedDay = day
    }

    func isEligible(completedLevels: Int, at date: Date) -> Bool {
        guard engagedDays >= 3, completedLevels >= 10,
              completedLevels - completionsAtLastRequest >= 10 else { return false }
        if let last = requestedAt.max(), date.timeIntervalSince(last) < 120 * 86_400 { return false }
        return requestedAt.filter { date.timeIntervalSince($0) < 365 * 86_400 }.count < 3
    }

    @discardableResult
    mutating func recordRequest(completedLevels: Int, at date: Date) -> Bool {
        guard isEligible(completedLevels: completedLevels, at: date) else { return false }
        requestedAt = requestedAt.filter { date.timeIntervalSince($0) < 365 * 86_400 }
        requestedAt.append(date)
        completionsAtLastRequest = completedLevels
        return true
    }
}
