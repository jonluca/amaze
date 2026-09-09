import Foundation

/// Reproduce with `swift run --package-path ios/EnginePackage -c release
/// MazePerfectCountCatalogGenerator`; pass --verify or --check for saved proofs.
/// Use --regenerate-changed after intentionally changing the seed catalog to retain
/// matching proofs and natively reprove only changed boards. Geometry drift is
/// rejected by every other mode; all 1,000 boards must have unique cell shapes.
@main
struct MazePerfectCountCatalogGenerator {
    private static let levelCount = 1_000

    private struct Grid: Codable, Hashable, Sendable {
        let width: Int
        let height: Int
        let startIndex: Int
        /// Sorted indices using row * 16 + column, independent of board width.
        let openCells: [Int]

        init(_ level: MazeLevel) {
            width = level.width
            height = level.height
            startIndex = level.start.row * 16 + level.start.column
            openCells = level.openCells.map { $0.row * 16 + $0.column }.sorted()
        }
    }

    private struct Proof: Codable, Sendable {
        let number: Int
        let grid: Grid
        let minimumMoves: Int
        let route: [MoveDirection]
    }

    private struct Artifact: Codable {
        let schemaVersion: Int
        let catalog: String
        let coordinateEncoding: String
        let proofMethod: String
        let entries: [Proof]

        init(entries: [Proof]) {
            schemaVersion = 1
            catalog = "Classic / endless / levels 1...1000"
            coordinateEncoding = "row * 16 + column"
            proofMethod = "CPrismOptimizer exact native optimum; complete route independently replayed on the raw grid"
            self.entries = entries.sorted { $0.number < $1.number }
        }
    }

    private struct Job: Sendable {
        let grid: Grid
        let level: MazeLevel
        let numbers: [Int]
    }

    private struct Solved: Sendable {
        let job: Job
        let minimum: Int
        let route: [MoveDirection]
        let seconds: Double
    }

    private struct CatalogError: Error, CustomStringConvertible {
        let description: String
    }

    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.isEmpty || arguments == ["--verify"] || arguments == ["--check"]
                || arguments == ["--regenerate-changed"] else {
            throw CatalogError(description: "Usage: MazePerfectCountCatalogGenerator [--verify|--check|--regenerate-changed]")
        }
        let regenerateChanged = arguments == ["--regenerate-changed"]
        let checking = arguments == ["--check"]
        let verifying = checking || arguments == ["--verify"]
        let ios = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent()
        let proofURL = ios.appendingPathComponent("Validation/PerfectCounts/classic-1-1000.json")
        let swiftURL = ios.appendingPathComponent("PrismRoll/Core/MazePerfectMoveCatalog+Generated.swift")
        let clock = ContinuousClock()
        let started = clock.now
        var levels: [MazeLevel] = []
        var grouped: [Grid: [Int]] = [:]
        for number in 1...levelCount {
            let level = MazeLevel.generate(number: number, mode: .endless)
            levels.append(level)
            grouped[Grid(level), default: []].append(number)
            if number.isMultiple(of: 100) { progress("Prepared current geometry for \(number)/\(levelCount) levels") }
        }
        progress("Catalog contains \(grouped.count) distinct full grid/start identities")
        let uniqueShapes = Set(grouped.keys.map { [$0.width, $0.height] + $0.openCells })
        guard grouped.count == levelCount, uniqueShapes.count == levelCount else {
            throw CatalogError(description: "Classic levels must have 1,000 unique cell shapes; regenerate the seed catalog first")
        }

        var saved: [Int: Proof] = [:]
        var byGrid: [Grid: Proof] = [:]
        if FileManager.default.fileExists(atPath: proofURL.path) {
            let artifact = try JSONDecoder().decode(Artifact.self, from: Data(contentsOf: proofURL))
            guard artifact.schemaVersion == 1, artifact.coordinateEncoding == "row * 16 + column" else {
                throw CatalogError(description: "Unsupported saved proof schema")
            }
            var loadedNumbers: Set<Int> = []
            for proof in artifact.entries {
                guard (1...levelCount).contains(proof.number), loadedNumbers.insert(proof.number).inserted else {
                    throw CatalogError(description: "Invalid or duplicate saved level identity \(proof.number)")
                }
                if proof.grid != Grid(levels[proof.number - 1]) {
                    guard regenerateChanged else {
                        throw CatalogError(description: "Saved proof geometry mismatch for level \(proof.number); use --regenerate-changed only for an intentional catalog change")
                    }
                    continue
                }
                try verify(proof, level: levels[proof.number - 1])
                if let existing = byGrid[proof.grid], existing.minimumMoves != proof.minimumMoves {
                    throw CatalogError(description: "Conflicting saved minima for identical geometry")
                }
                saved[proof.number] = proof
                byGrid[proof.grid] = proof
            }
            progress("Validated \(saved.count) saved routes against current generated grids")
        } else if verifying {
            throw CatalogError(description: "No saved proof artifact at \(proofURL.path)")
        }

        if !verifying {
            let jobs = grouped.compactMap { grid, numbers -> Job? in
                if let existing = byGrid[grid] {
                    for number in numbers {
                        saved[number] = Proof(number: number, grid: grid,
                                              minimumMoves: existing.minimumMoves, route: existing.route)
                    }
                    return nil
                }
                return Job(grid: grid, level: levels[numbers[0] - 1], numbers: numbers)
            }.sorted { $0.numbers[0] < $1.numbers[0] }
            progress("Solving \(jobs.count) new distinct grids with two native workers; checkpoints save each completed proof")
            try await withThrowingTaskGroup(of: Solved.self) { group in
                var next = 0
                for _ in 0..<min(2, jobs.count) {
                    let job = jobs[next]
                    next += 1
                    group.addTask { try solve(job) }
                }
                while let solved = try await group.next() {
                    for number in solved.job.numbers {
                        saved[number] = Proof(number: number, grid: solved.job.grid,
                                              minimumMoves: solved.minimum, route: solved.route)
                    }
                    try save(saved, to: proofURL)
                    progress(String(format: "Proved representative %d: %d moves, %.3fs; saved %d/%d levels",
                                    solved.job.numbers[0], solved.minimum, solved.seconds, saved.count, levelCount))
                    if next < jobs.count {
                        let job = jobs[next]
                        next += 1
                        group.addTask { try solve(job) }
                    }
                }
            }
        }

        guard saved.count == levelCount else {
            throw CatalogError(description: "Expected all \(levelCount) proofs, found \(saved.count)")
        }
        let proofs = (1...levelCount).map { saved[$0]! }
        for proof in proofs { try verify(proof, level: levels[proof.number - 1]) }
        let generated = generatedSwift(proofs)
        if checking {
            guard try String(contentsOf: swiftURL, encoding: .utf8) == generated else {
                throw CatalogError(description: "Generated Swift does not match the complete saved proof artifact")
            }
        } else if !verifying {
            try save(saved, to: proofURL)
            try Data(generated.utf8).write(to: swiftURL, options: .atomic)
        }
        let elapsed = seconds(started.duration(to: clock.now))
        progress(String(format: "%@ all %d exact counts and legal completing routes in %.3fs",
                        verifying ? "Verified" : "Generated", levelCount, elapsed))
    }

    private static func solve(_ job: Job) throws -> Solved {
        let clock = ContinuousClock()
        let started = clock.now
        // Deliberately bypass MazePerfectMoveCatalog, MazeOptimality and every
        // cache: a new persisted number must come from an actual native proof.
        let result = MazeNativeOptimizer.solve(level: job.level, isCancelled: { Task.isCancelled })
        guard case let .optimal(minimum, route) = result else {
            throw CatalogError(description: "No exact native proof for level \(job.numbers[0]): \(result)")
        }
        let proof = Proof(number: job.numbers[0], grid: job.grid, minimumMoves: minimum, route: route)
        try verify(proof, level: job.level)
        return Solved(job: job, minimum: minimum, route: route,
                      seconds: seconds(started.duration(to: clock.now)))
    }

    private static func verify(_ proof: Proof, level: MazeLevel) throws {
        guard proof.grid == Grid(level), proof.minimumMoves >= 0,
              proof.route.count == proof.minimumMoves else {
            throw CatalogError(description: "Invalid count/grid metadata for level \(proof.number)")
        }
        var position = level.start
        var painted: Set<GridCell> = [position]
        // Literal slides intentionally do not call MazeSolver.path or the
        // native graph/reconstruction, keeping this replay independent.
        for direction in proof.route {
            guard painted != level.openCells else {
                throw CatalogError(description: "Proof continues after completion at level \(proof.number)")
            }
            let delta: (row: Int, column: Int)
            switch direction {
            case .up: delta = (-1, 0)
            case .down: delta = (1, 0)
            case .left: delta = (0, -1)
            case .right: delta = (0, 1)
            }
            let before = position
            while true {
                let next = GridCell(row: position.row + delta.row, column: position.column + delta.column)
                guard level.openCells.contains(next) else { break }
                position = next
                painted.insert(next)
            }
            guard position != before else {
                throw CatalogError(description: "Blocked swipe in proof for level \(proof.number)")
            }
        }
        guard painted == level.openCells else {
            throw CatalogError(description: "Incomplete proof route for level \(proof.number)")
        }
    }

    private static func save(_ proofs: [Int: Proof], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(Artifact(entries: Array(proofs.values))).write(to: url, options: .atomic)
    }

    private static func generatedSwift(_ proofs: [Proof]) -> String {
        var lines = [
            "// Generated by MazePerfectCountCatalogGenerator. Do not edit counts by hand.",
            "// Exact native proofs and independently replayable routes:",
            "// ios/Validation/PerfectCounts/classic-1-1000.json",
            "extension MazePerfectMoveCatalog {",
            "    static let entries: [Entry] = ["
        ]
        for proof in proofs {
            var masks = [UInt64](repeating: 0, count: 4)
            for index in proof.grid.openCells { masks[index / 64] |= UInt64(1) << (index % 64) }
            let fields = ["width: \(proof.grid.width)", "height: \(proof.grid.height)",
                          "startIndex: \(proof.grid.startIndex)"]
                + masks.enumerated().map { "mask\($0.offset): 0x\(String($0.element, radix: 16))" }
                + ["minimumMoves: \(proof.minimumMoves)"]
            lines.append("        Entry(\(fields.joined(separator: ", "))), // Level \(proof.number)")
        }
        lines += ["    ]", "}", ""]
        return lines.joined(separator: "\n")
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    private static func progress(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
