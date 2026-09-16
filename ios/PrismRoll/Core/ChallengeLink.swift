import Foundation

enum ChallengeLink {
    static let website = "https://thoughtahead.com/prism-roll/challenge/"
    private static let directionCodes: [Character: MoveDirection] = ["U": .up, "D": .down, "L": .left, "R": .right]

    static func make(level: MazeLevel, title: String, moves: Int? = nil) throws -> SharedChallenge {
        guard (2...16).contains(level.width), (2...16).contains(level.height),
              (0..<level.height).contains(level.start.row), (0..<level.width).contains(level.start.column),
              level.openCells.allSatisfy({ (0..<level.height).contains($0.row) && (0..<level.width).contains($0.column) }),
              (1...2_048).contains(level.solution.count) else {
            throw ChallengeLinkError.invalidPuzzle
        }
        let occupancy = (0..<(level.width * level.height)).map { index in
            level.openCells.contains(GridCell(row: index / level.width, column: index % level.width)) ? "1" : "0"
        }.joined()
        let route = level.solution.map { direction in
            switch direction {
            case .up: "U"
            case .down: "D"
            case .left: "L"
            case .right: "R"
            }
        }.joined()
        let payload = ChallengePayload(w: level.width, h: level.height,
                                       s: level.start.row * level.width + level.start.column,
                                       o: occupancy, t: title, m: moves, r: route)
        return try challenge(from: payload)
    }

    static func decode(_ url: URL) throws -> SharedChallenge {
        guard url.absoluteString.utf8.count <= 8_192,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.port == nil,
              components.fragment == nil else { throw ChallengeLinkError.invalidLink }
        let isWebsite = components.scheme?.lowercased() == "https"
            && components.host?.lowercased() == "thoughtahead.com"
            && ["/prism-roll/challenge/", "/prism-roll/challenge"].contains(components.path)
        let isAppLink = components.scheme?.lowercased() == "prismroll"
            && components.host?.lowercased() == "challenge"
            && ["", "/"].contains(components.path)
        guard isWebsite || isAppLink, let items = components.queryItems, items.count == 2,
              items.filter({ $0.name == "v" }).count == 1,
              items.filter({ $0.name == "p" }).count == 1,
              let version = items.first(where: { $0.name == "v" })?.value else {
            throw ChallengeLinkError.invalidLink
        }
        guard version == "1" else { throw ChallengeLinkError.unsupportedVersion }
        guard let encoded = items.first(where: { $0.name == "p" })?.value,
              !encoded.isEmpty, encoded.utf8.count <= 6_000,
              encoded.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0)
                  || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw ChallengeLinkError.invalidLink
        }
        let base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64 + padding), data.count <= 4_096,
              let payload = try? JSONDecoder().decode(ChallengePayload.self, from: data) else {
            throw ChallengeLinkError.invalidLink
        }
        return try challenge(from: payload)
    }

    private static func challenge(from payload: ChallengePayload) throws -> SharedChallenge {
        guard (2...16).contains(payload.w), (2...16).contains(payload.h),
              (0..<(payload.w * payload.h)).contains(payload.s),
              payload.o.utf8.count == payload.w * payload.h,
              payload.o.utf8.allSatisfy({ $0 == 48 || $0 == 49 }),
              !payload.t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              payload.t.count <= 80,
              !payload.t.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              payload.m.map({ (1...100_000).contains($0) }) ?? true,
              (1...2_048).contains(payload.r.utf8.count) else { throw ChallengeLinkError.invalidPuzzle }
        let cells = Set(payload.o.utf8.enumerated().compactMap { index, value -> GridCell? in
            value == 49 ? GridCell(row: index / payload.w, column: index % payload.w) : nil
        })
        let start = GridCell(row: payload.s / payload.w, column: payload.s % payload.w)
        let route = payload.r.compactMap { directionCodes[$0] }
        guard cells.count >= 2, cells.contains(start), route.count == payload.r.count else {
            throw ChallengeLinkError.invalidPuzzle
        }
        var position = start
        var painted: Set<GridCell> = [start]
        for direction in route {
            let path = MazeSolver.path(from: position, direction: direction, in: cells)
            guard let destination = path.last else { throw ChallengeLinkError.invalidPuzzle }
            position = destination
            painted.formUnion(path)
        }
        guard painted == cells else { throw ChallengeLinkError.invalidPuzzle }
        let level = MazeLevel(number: 1, mode: .endless, width: payload.w, height: payload.h,
                              openCells: cells, start: start, solution: route, moveLimit: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        guard data.count <= 4_096 else { throw ChallengeLinkError.invalidPuzzle }
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        guard let url = URL(string: "\(website)?v=1&p=\(encoded)") else { throw ChallengeLinkError.invalidLink }
        return SharedChallenge(level: level, title: payload.t, senderMoves: payload.m, url: url)
    }
}
