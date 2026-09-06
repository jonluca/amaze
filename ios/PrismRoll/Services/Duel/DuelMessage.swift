import Foundation

/// Reliable, bounded, versioned peer messages. No economy or account state is transmitted.
enum DuelMessage: Codable, Sendable {
    case hello(version: Int)
    case setup(id: String, seed: Int)
    case ready(id: String)
    case start(id: String)
    case progress(id: String, painted: Int, total: Int, moves: Int)
    case finish(id: String)
    case result(id: String, winner: String)
}
