import Foundation

@MainActor
final class ReviewPromptStore {
    private let defaults: UserDefaults
    private let key = "prism.review-policy.v1"
    private var policy: ReviewPromptPolicy

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        policy = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ReviewPromptPolicy.self, from: $0) }
            ?? ReviewPromptPolicy()
    }

    func recordEngagement(at date: Date = Date()) {
        policy.recordEngagement(at: date)
        persist()
    }

    /// A request is persisted even if StoreKit elects not to display its system sheet.
    func consumeRequest(completedLevels: Int, at date: Date = Date()) -> Bool {
        guard policy.recordRequest(completedLevels: completedLevels, at: date) else { return false }
        persist()
        return true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(policy) else { return }
        defaults.set(data, forKey: key)
    }
}
