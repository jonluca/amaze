import Foundation

/// Compile with the Core sources, then run to compare independently seeded processes.
@main
struct LevelCatalogAudit {
    static let numbers = [1, 2, 4, 5, 7, 10, 15, 22, 30, 42, 56, 75, 100, 150, 200, 10_000, Int.max]

    static func main() throws {
        if CommandLine.arguments.contains("--snapshot") {
            var requests = GameMode.allCases.flatMap { mode in numbers.map { (mode, $0) } }
            if CommandLine.arguments.contains("--reverse") { requests.reverse() }
            let rows = requests.map { mode, number in
                describe(MazeLevel.generate(number: number, mode: mode))
            }
            print(rows.sorted().joined(separator: "\n"))
            return
        }

        let baseline = try snapshot(deterministicHashing: false, reverse: false)
        for configuration in [(false, false), (false, true), (true, true)] {
            let actual = try snapshot(deterministicHashing: configuration.0, reverse: configuration.1)
            guard actual == baseline else {
                throw NSError(domain: "LevelCatalogAudit", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Numbered levels changed with process hash seed or generation order."
                ])
            }
        }
        print("Verified \(numbers.count * GameMode.allCases.count) numbered levels across four independent processes, randomized/fixed hashing, and reversed generation order.")
    }

    static func snapshot(deterministicHashing: Bool, reverse: Bool) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = reverse ? ["--snapshot", "--reverse"] : ["--snapshot"]
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "SWIFT_DETERMINISTIC_HASHING")
        if deterministicHashing { environment["SWIFT_DETERMINISTIC_HASHING"] = "1" }
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "LevelCatalogAudit", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Catalog snapshot subprocess failed."
            ])
        }
        return data
    }

    static func describe(_ level: MazeLevel) -> String {
        let cells = level.openCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
        let coins = level.coinCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
        let route = level.solution.map(\.rawValue).joined(separator: ",")
        return "\(level.mode.rawValue)|\(level.number)|\(level.width)x\(level.height)|\(level.start.row),\(level.start.column)|\(cells)|\(coins)|\(route)|\(level.moveLimit ?? -1)|\(level.timeLimit ?? -1)"
    }
}
