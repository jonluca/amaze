import Foundation

/// Keeps the wallet and receipt ledger in one atomic file, independently of
/// frequently changing run snapshots. Owned synchronously by GameStore.
final class ProgressPersistence {
    private let url: URL?
    private var cached: ProgressData?
    private var unreadable = false

    init(url: URL?) { self.url = url }

    static func defaultURL(for defaults: UserDefaults) -> URL? {
        guard defaults === UserDefaults.standard else { return nil }
        return URL.applicationSupportDirectory.appending(path: "PrismRoll/progress.json")
    }

    func load() throws -> ProgressData? {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let progress = try JSONDecoder().decode(ProgressData.self, from: Data(contentsOf: url))
            cached = progress
            return progress
        } catch {
            unreadable = true
            throw error
        }
    }

    func persist(_ progress: ProgressData) throws {
        guard !unreadable else { throw CocoaError(.fileReadCorruptFile) }
        guard cached != progress else { return }
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(progress).write(to: url, options: .atomic)
        }
        cached = progress
    }

    var supportsDurablePurchases: Bool { url != nil && !unreadable }

#if DEBUG
    func resetForUITesting() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
        cached = nil
        unreadable = false
    }
#endif
}
