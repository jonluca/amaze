import Foundation

struct AppsFlyerConfiguration {
    static let appleAppID = "6809253424"
    let developerKey: String

    init?(developerKey: String?) {
        guard let key = developerKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty, key.count <= 256,
              !key.contains(where: { $0.isWhitespace }),
              !key.contains("$("), !key.contains("<"), !key.contains(">"),
              !["placeholder", "your_dev_key", "your-dev-key", "replace_me"].contains(key.lowercased()) else { return nil }
        self.developerKey = key
    }

    init?(bundle: Bundle) {
        self.init(developerKey: bundle.object(forInfoDictionaryKey: "PrismAppsFlyerDevKey") as? String)
    }
}
