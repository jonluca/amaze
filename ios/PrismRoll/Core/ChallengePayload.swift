import Foundation

/// Version 1 link schema. Occupancy is row-major; the route proves the board is playable.
struct ChallengePayload: Codable {
    let w: Int
    let h: Int
    let s: Int
    let o: String
    let t: String
    let m: Int?
    let r: String
}
