import Foundation

/// Run `swift run --package-path ios/EnginePackage -c release
/// MazeClassicSeedCatalogGenerator` to generate the current seed catalog, or add
/// --check to verify it. Then run MazePerfectCountCatalogGenerator
/// --regenerate-changed followed by --check to update and verify exact proofs.
/// Each level selects the first variation, starting at zero, that meets the
/// normal difficulty gates and has a cell layout unused by earlier levels.
@main
struct MazeClassicSeedCatalogGenerator {
    private static let levelCount = 1_000

    private struct Grid: Codable, Hashable {
        let width: Int
        let height: Int
        let startIndex: Int
        let openCells: [Int]

        init(_ level: MazeLevel) {
            width = level.width
            height = level.height
            startIndex = level.start.row * 16 + level.start.column
            openCells = level.openCells.map { $0.row * 16 + $0.column }.sorted()
        }

        var shape: [Int] { [width, height] + openCells }
    }

    private struct Selection: Codable {
        let number: Int
        let variation: UInt64
        let grid: Grid
    }

    private struct Catalog: Codable {
        let schemaVersion: Int
        let catalog: String
        let coordinateEncoding: String
        let entries: [Selection]

        init(_ entries: [Selection]) {
            schemaVersion = 1
            catalog = "Classic / endless / levels 1...1000"
            coordinateEncoding = "row * 16 + column"
            self.entries = entries
        }
    }

    private struct GenerationError: Error, CustomStringConvertible {
        let description: String
    }

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.isEmpty || arguments == ["--check"] else {
            throw GenerationError(description: "Usage: MazeClassicSeedCatalogGenerator [--check]")
        }
        let checking = arguments == ["--check"]
        let ios = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = ios.appendingPathComponent("PrismRoll/Core/MazeClassicBoardSeeds.swift")
        let catalogURL = ios.appendingPathComponent("Validation/PerfectCounts/classic-seeds-1-1000.json")
        let started = ContinuousClock.now
        var occupiedShapes: Set<[Int]> = []
        var selections: [Selection] = []
        for number in 1...levelCount {
            let difficulty = MazeDifficulty(number: number, mode: .endless)
            var variation: UInt64 = 0
            while true {
                let candidate = MazeLevel.generateProcedural(number: number, mode: .endless,
                                                            difficultyNumber: number, variation: variation)
                let grid = Grid(candidate)
                if !occupiedShapes.contains(grid.shape),
                   let accepted = MazeLayout.candidate(cells: candidate.openCells, difficulty: difficulty,
                                                       preferredStart: candidate.start),
                   accepted.cells == candidate.openCells {
                    occupiedShapes.insert(grid.shape)
                    selections.append(Selection(number: number, variation: variation, grid: grid))
                    if variation != 0 || number.isMultiple(of: 100) {
                        progress("Level \(number): selected variation \(variation); \(selections.count)/\(levelCount) unique boards")
                    }
                    break
                }
                guard variation < UInt64.max else {
                    throw GenerationError(description: "Exhausted deterministic variations for level \(number)")
                }
                variation += 1
            }
        }

        var verifiedGrids: Set<Grid> = []
        var verifiedShapes: Set<[Int]> = []
        for selection in selections {
            let level = MazeLevel.generateProcedural(number: selection.number, mode: .endless,
                                                    difficultyNumber: selection.number, variation: selection.variation)
            let grid = Grid(level)
            guard grid == selection.grid, verifiedGrids.insert(grid).inserted,
                  verifiedShapes.insert(grid.shape).inserted,
                  let accepted = MazeLayout.candidate(cells: level.openCells,
                                                       difficulty: MazeDifficulty(number: level.number, mode: .endless),
                                                       preferredStart: level.start),
                  accepted.cells == level.openCells else {
                throw GenerationError(description: "Invalid, repeated, or nondeterministic board at level \(selection.number)")
            }
        }
        guard verifiedGrids.count == levelCount, verifiedShapes.count == levelCount else {
            throw GenerationError(description: "Incomplete unique Classic catalog")
        }

        let source = generatedSwift(selections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let catalog = try encoder.encode(Catalog(selections))
        if checking {
            guard try String(contentsOf: sourceURL, encoding: .utf8) == source,
                  try Data(contentsOf: catalogURL) == catalog else {
                throw GenerationError(description: "Seed catalog does not match deterministic sequential generation")
            }
        } else {
            try FileManager.default.createDirectory(at: catalogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try catalog.write(to: catalogURL, options: .atomic)
            try Data(source.utf8).write(to: sourceURL, options: .atomic)
        }
        let duration = started.duration(to: .now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        progress(String(format: "%@ %d unique Classic boards, all meeting the existing difficulty gates; %.3fs",
                        checking ? "Verified" : "Generated", levelCount, seconds))
    }

    private static func generatedSwift(_ selections: [Selection]) -> String {
        var lines = [
            "// Generated by MazeClassicSeedCatalogGenerator. Bundled unique Classic seed choices.",
            "// Catalog: ios/Validation/PerfectCounts/classic-seeds-1-1000.json",
            "enum MazeClassicBoardSeeds {",
            "    static func variation(for number: Int) -> UInt64 {",
            "        switch number {"
        ]
        for selection in selections where selection.variation != 0 {
            lines.append("        case \(selection.number): return \(selection.variation)")
        }
        lines += ["        default: return 0", "        }", "    }", "}", ""]
        return lines.joined(separator: "\n")
    }

    private static func progress(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
