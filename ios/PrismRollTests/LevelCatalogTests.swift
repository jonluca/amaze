import XCTest
@testable import PrismRoll

final class LevelCatalogTests: XCTestCase {
    func testNumberedCatalogMatchesFrozenFixtures() {
        // These fixtures preserve players' numbered boards across app updates.
        // Capture all geometry, start, coins, route, and budgets in a stable order.
        let fixtures: [(GameMode, Int, UInt64)] = [
            (.endless, 1, 0x40E9DA9C612B22CB),
            (.endless, 2, 0xFC591EF2D006B0B2),
            (.endless, 4, 0x666990ACBB57BBE8),
            (.endless, 5, 0xFEAB0DFDB6EDB933),
            (.endless, 7, 0xB8810EA793B1E2F6),
            (.endless, 10, 0xB82AE8604785C4E1),
            (.endless, 15, 0x72D0A5CFF75BF99E),
            (.endless, 22, 0xAAFF3CA829D4410F),
            (.endless, 30, 0xA09350CF3E8DB026),
            (.endless, 42, 0x724498C6FB8215A2),
            (.endless, 56, 0x86C4368EF3802F3C),
            (.endless, 75, 0x84CA995A4A206F05),
            (.endless, 100, 0x9B125DA2648C0355),
            (.endless, 150, 0x236608B211BA3ABD),
            (.endless, 200, 0xEA8EF93E48EB59B7),
            (.endless, 10000, 0xA34918C085B2EEC8),
            (.endless, Int.max, 0xADA4906B6EF87214),
            (.challenge, 1, 0x6F79CDDD0B5DDFF0),
            (.challenge, 2, 0xA5DC5D2842568FDE),
            (.challenge, 4, 0xD88FDD5FF25BD345),
            (.challenge, 5, 0x3344610810921826),
            (.challenge, 7, 0xA12B3CFC2BF96B90),
            (.challenge, 10, 0x8E4C05D6CE1E7E8A),
            (.challenge, 15, 0x347A09C5FC531C94),
            (.challenge, 22, 0xEDFF54A56E4FA76F),
            (.challenge, 30, 0x76A9E965D48699FC),
            (.challenge, 42, 0x0C980B71060A5B58),
            (.challenge, 56, 0x6D8D7412BB174239),
            (.challenge, 75, 0xCD88219D0A9E70F7),
            (.challenge, 100, 0x006AF10FEC2F8BFC),
            (.challenge, 150, 0x57D2FE85B538CAB2),
            (.challenge, 200, 0xDE9EE0BBF18B5D45),
            (.challenge, 10000, 0x66FFB0E8DE639E5C),
            (.challenge, Int.max, 0xEDDB1C1E62DF56A5),
            (.timed, 1, 0x621294C833EA6E12),
            (.timed, 2, 0xA871A3DB7A135120),
            (.timed, 4, 0x9A864E733F825BEC),
            (.timed, 5, 0xB87F01738C273171),
            (.timed, 7, 0x11EB94818D3C94AA),
            (.timed, 10, 0x2A1A7CBF28D96141),
            (.timed, 15, 0x0F648EAD5E5EC75D),
            (.timed, 22, 0x057C47980D2A5787),
            (.timed, 30, 0x9DC2E0EDFF333D09),
            (.timed, 42, 0xDE83A24A85B94943),
            (.timed, 56, 0x42F0A0456886A88B),
            (.timed, 75, 0x9AD768CACFB16258),
            (.timed, 100, 0x096FA5D8E62EB81D),
            (.timed, 150, 0xE0BB0318C3792632),
            (.timed, 200, 0x0F8CE6E8E88A5E97),
            (.timed, 10000, 0x8CCF9A0FE486D2E8),
            (.timed, Int.max, 0xE9C9C30E82D1C589),
        ]
        for (mode, number, expected) in fixtures {
            let level = MazeLevel.generate(number: number, mode: mode)
            XCTAssertEqual(fingerprint(level), expected, "Catalog changed for \(mode) level \(number)")
        }
    }

    func testLevelTenUsesTheSamePublishedGridForEveryMode() {
        let fixtures: [(GameMode, [String])] = [
            (.endless, [
                "##.##.##.", "##.##....", "##..##.#.", ".#..##...", ".......##",
                ".#......#", "......#..", "..#......", "#S.....#."
            ]),
            (.challenge, [
                "S..#.#.#..", ".#.#......", "...###....", "##.#....#.", "##....#..#",
                "###.......", "...##.#..#", ".#........", "###...#...", "###.####.."
            ]),
            (.timed, [
                "S.#..#....", ".##....##.", "...#..###.", "...#..###.", "#.....#...",
                "##..#...#.", ".###.#..##", ".###.#....", ".....#.##.", "..#....##."
            ])
        ]
        for (mode, expected) in fixtures {
            let level = MazeLevel.generate(number: 10, mode: mode)
            let rows = (0..<level.height).map { row in
                (0..<level.width).map { column in
                    let cell = GridCell(row: row, column: column)
                    return cell == level.start ? "S" : level.openCells.contains(cell) ? "." : "#"
                }.joined()
            }
            XCTAssertEqual(rows, expected, "\(mode) level 10")
        }
    }

    func testGridCompatibilityIgnoresMetadataButDetectsGeometryChanges() {
        let cells: Set<GridCell> = [
            GridCell(row: 0, column: 0), GridCell(row: 0, column: 1), GridCell(row: 1, column: 1)
        ]
        let start = GridCell(row: 0, column: 0)
        let original = MazeLevel(number: 1, mode: .endless, width: 2, height: 2,
            openCells: cells, start: start, solution: [.right, .down], moveLimit: nil)
        func other(width: Int, height: Int, start: GridCell, cells: Set<GridCell>) -> MazeLevel {
            MazeLevel(number: 2, mode: .challenge, width: width, height: height,
                openCells: cells, start: start, solution: [], moveLimit: 9,
                timeLimit: 30, coinCells: [GridCell(row: 0, column: 1)])
        }
        XCTAssertTrue(original.hasSameGrid(as: other(width: 2, height: 2, start: start, cells: cells)))
        XCTAssertFalse(original.hasSameGrid(as: other(width: 3, height: 2, start: start, cells: cells)))
        XCTAssertFalse(original.hasSameGrid(as: other(width: 2, height: 3, start: start, cells: cells)))
        XCTAssertFalse(original.hasSameGrid(as: other(width: 2, height: 2,
            start: GridCell(row: 0, column: 1), cells: cells)))
        XCTAssertFalse(original.hasSameGrid(as: other(width: 2, height: 2, start: start,
            cells: cells.union([GridCell(row: 1, column: 0)]))))
    }

    private func fingerprint(_ level: MazeLevel) -> UInt64 {
        let cells = level.openCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
        let coins = level.coinCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
        let route = level.solution.map(\.rawValue).joined(separator: ",")
        let signature = "\(level.mode.rawValue)|\(level.number)|\(level.width)x\(level.height)|\(level.start.row),\(level.start.column)|\(cells)|\(coins)|\(route)|\(level.moveLimit ?? -1)|\(level.timeLimit ?? -1)"
        // Explicit FNV-1a, never Swift.Hasher (which is randomized per process).
        return signature.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
    }
}
