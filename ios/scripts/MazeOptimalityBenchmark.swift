import Foundation

/// Run with swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark.
/// Times only the exact native minimum calculation, including model construction.
/// Reference minima were independently proved by integer flow optimization and
/// their complete routes replayed against the raw grids; see OPTIMAL_SOLVER.md.
@main
struct MazeOptimalityBenchmark {
    static func main() throws {
        let reference: [(number: Int, minimum: Int)] = [
            (1, 8),
            (2, 19),
            (3, 17),
            (4, 20),
            (5, 20),
            (6, 19),
            (7, 28),
            (8, 28),
            (9, 26),
            (10, 31),
            (11, 34),
            (12, 32),
            (13, 34),
            (14, 36),
            (15, 43),
            (16, 38),
            (17, 39),
            (18, 39),
            (19, 40),
            (20, 46),
            (21, 40),
            (22, 51),
            (23, 44),
            (24, 47),
            (25, 42),
            (26, 42),
            (27, 42),
            (28, 50),
            (29, 46),
            (30, 58),
            (31, 51),
            (32, 53),
            (33, 52),
            (34, 51),
            (35, 48),
            (36, 55),
            (37, 57),
            (38, 56),
            (39, 54),
            (40, 52),
            (41, 53),
            (42, 62),
            (43, 56),
            (44, 56),
            (45, 61),
            (46, 58),
            (47, 61),
            (48, 58),
            (49, 60),
            (50, 58),
            (51, 57),
            (52, 61),
            (53, 59),
            (54, 58),
            (55, 54),
            (56, 62),
            (57, 63),
            (58, 64),
            (59, 65),
            (60, 62),
            (61, 65),
            (62, 67),
            (63, 68),
            (64, 66),
            (65, 65),
            (66, 63),
            (67, 65),
            (68, 60),
            (69, 75),
            (70, 68),
            (71, 66),
            (72, 65),
            (73, 62),
            (74, 62),
            (75, 74),
            (76, 80),
            (77, 79),
            (78, 79),
            (79, 77),
            (80, 80),
            (81, 76),
            (82, 77),
            (83, 77),
            (84, 81),
            (85, 75),
            (86, 82),
            (87, 80),
            (88, 78),
            (89, 81),
            (90, 76),
            (91, 71),
            (92, 80),
            (93, 80),
            (94, 79),
            (95, 73),
            (96, 80),
            (97, 80),
            (98, 77),
            (99, 74),
            (100, 90),
            (150, 94),
            (200, 91),
            (250, 88),
            (500, 91),
            (1000, 88),
            (1001, 85),
            (10000, 86),
            (100000, 89),
            (1000000, 89),
            (1000000000, 89),
            (Int.max, 92)
        ]
        let clock = ContinuousClock()
        var results: [[String: Any]] = []
        var proved = 0
        for item in reference {
            let level = MazeLevel.generate(number: item.number, mode: .endless)
            let start = clock.now
            guard let minimum = MazeOptimality.minimumMoves(for: level) else {
                fatalError("No exact result for level \(item.number)")
            }
            let duration = start.duration(to: clock.now).components
            let milliseconds = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
            precondition(minimum == item.minimum, "Incorrect minimum for level \(item.number): \(minimum) != \(item.minimum)")
            proved += 1
            let result: [String: Any] = [
                "level": item.number, "minimum": minimum,
                "reference": item.minimum, "milliseconds": milliseconds
            ]
            results.append(result)
            print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
        }
        print("Proved \(proved)/\(reference.count); every reported minimum matches the independent oracle.")
        if let output = CommandLine.arguments.dropFirst().first {
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: output))
        }
    }
}
