import Foundation

struct LoadedAd<Ad> {
    let ad: Ad
    let loadedAt = Date()

    // Google ads expire after an hour; leave a five-minute safety margin.
    var isFresh: Bool { Date().timeIntervalSince(loadedAt) < 55 * 60 }
}
