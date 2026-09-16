import Foundation
import simd

@main
enum MotionBenchmark {
    static func squareMoves(count: Int, length: Int) -> [MazeSceneMove] {
        let start = GridCell(row: 0, column: 0)
        let corners = [start, GridCell(row: 0, column: length), GridCell(row: length, column: length),
                       GridCell(row: length, column: 0), start]
        var painted: Set<GridCell> = [start]
        return (0..<count).map { index in
            let origin = corners[index % 4]
            let target = corners[index % 4 + 1]
            let path = (1...length).map { step in
                GridCell(row: origin.row + (target.row - origin.row) * step / length,
                         column: origin.column + (target.column - origin.column) * step / length)
            }
            painted.formUnion(path)
            return MazeSceneMove(origin: origin, path: path, position: target,
                                 painted: painted, isComplete: index == count - 1)
        }
    }

    // Validate each frame, including event ordering and every visible position.
    static func verifyParity(moves: [MazeSceneMove], spacing: Double, fps: Double) {
        var array = ArrayMotionTimeline()
        var deque = DequeMotionTimeline()
        array.reset(position: moves[0].origin, painted: [moves[0].origin])
        deque.reset(position: moves[0].origin, painted: [moves[0].origin])
        var next = 0
        var frame = 0
        repeat {
            let elapsed = Double(frame) / fps
            while next < moves.count, Double(next) * spacing <= elapsed + 0.000001 {
                array.enqueue(moves[next])
                deque.enqueue(moves[next])
                next += 1
            }
            let a = array.advance(by: 1 / fps)
            let d = deque.advance(by: 1 / fps)
            precondition(a.paintedCells == d.paintedCells)
            precondition(a.rotations == d.rotations)
            precondition(a.completedAt == d.completedAt)
            precondition(a.wallImpactDirection == d.wallImpactDirection)
            precondition(array.position == deque.position)
            precondition(array.painted == deque.painted)
            precondition(array.pendingMoveCount == deque.pendingMoveCount)
            frame += 1
            precondition(frame < 100_000)
        } while next < moves.count || array.isMoving || deque.isMoving
    }

    // All input fixtures are created outside timing. The queue retains capacity
    // between bursts, matching a persistent renderer's timeline.
    @inline(never)
    static func queueWork<Q: BenchmarkQueue>(_: Q.Type, moves: [MazeSceneMove], iterations: Int) -> Int {
        var queue = Q()
        var checksum = 0
        for _ in 0..<iterations {
            for move in moves { queue.append(move) }
            while !queue.isEmpty {
                let move = queue.removeFirst()
                checksum &+= move.path.count + move.painted.count + move.position.row + move.position.column
            }
        }
        return checksum
    }

    @inline(never)
    static func timelineWork<T: BenchmarkTimeline>(_: T.Type, moves: [MazeSceneMove],
                                                   iterations: Int, spacing: Double, fps: Double) -> Int {
        var timeline = T()
        var checksum = 0
        for _ in 0..<iterations {
            timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
            var next = 0
            var frame = 0
            repeat {
                let elapsed = Double(frame) / fps
                while next < moves.count, Double(next) * spacing <= elapsed + 0.000001 {
                    timeline.enqueue(moves[next])
                    next += 1
                }
                let update = timeline.advance(by: 1 / fps)
                checksum &+= update.paintedCells.count + update.rotations.count
                checksum &+= Int(timeline.position.x * 1_000) + Int(timeline.position.y * 1_000)
                checksum &+= (update.completedAt == nil ? 0 : 1)
                frame += 1
            } while next < moves.count || timeline.isMoving
            checksum &+= timeline.painted.count
        }
        return checksum
    }

    static func measure(iterations: Int, _ work: () -> Int) -> (Double, Int) {
        let start = DispatchTime.now().uptimeNanoseconds
        let checksum = work()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        return (Double(elapsed) / Double(iterations), checksum)
    }

    static func main() throws {
        let sampleCount = 9
        var results: [[String: Any]] = []
        var parityCases = 0
        for count in [1, 4, 8, 16, 128, 1_024] {
            for length in [1, 4, 10] {
                let moves = squareMoves(count: count, length: length)
                for fps in [30.0, 60.0, 120.0] {
                    verifyParity(moves: moves, spacing: 0, fps: fps)
                    parityCases += 1
                }
            }
        }
        for spacing in [0.025, 0.05, 0.09] {
            for fps in [30.0, 60.0, 120.0] {
                verifyParity(moves: squareMoves(count: 64, length: 4), spacing: spacing, fps: fps)
                parityCases += 1
            }
        }
        for mode in ["queue_only", "timeline_burst_120hz", "timeline_sustained_120hz_25ms"] {
            let counts = mode.hasPrefix("timeline_sustained") ? [64] : [1, 4, 8, 16, 128, 1_024]
            for count in counts {
                let moves = squareMoves(count: count, length: 4)
                let spacing = mode.hasPrefix("timeline_sustained") ? 0.025 : 0.0
                let iterations = mode.hasPrefix("timeline_sustained") ? 500 : max(100, 200_000 / count)
                let arrayWork = {
                    mode == "queue_only"
                        ? queueWork(ArrayMoveQueue.self, moves: moves, iterations: iterations)
                        : timelineWork(ArrayMotionTimeline.self, moves: moves, iterations: iterations, spacing: spacing, fps: 120)
                }
                let dequeWork = {
                    mode == "queue_only"
                        ? queueWork(DequeMoveQueue.self, moves: moves, iterations: iterations)
                        : timelineWork(DequeMotionTimeline.self, moves: moves, iterations: iterations, spacing: spacing, fps: 120)
                }
                precondition(arrayWork() == dequeWork())
                var arraySamples: [Double] = []
                var dequeSamples: [Double] = []
                var checksum = 0
                // Alternate ordering to reduce systematic thermal/order bias.
                for sample in 0..<sampleCount {
                    if sample.isMultiple(of: 2) {
                        let a = measure(iterations: iterations, arrayWork)
                        let d = measure(iterations: iterations, dequeWork)
                        precondition(a.1 == d.1)
                        checksum &+= a.1 + d.1
                        arraySamples.append(a.0)
                        dequeSamples.append(d.0)
                    } else {
                        let d = measure(iterations: iterations, dequeWork)
                        let a = measure(iterations: iterations, arrayWork)
                        precondition(a.1 == d.1)
                        checksum &+= a.1 + d.1
                        arraySamples.append(a.0)
                        dequeSamples.append(d.0)
                    }
                }
                let arrayMedian = arraySamples.sorted()[sampleCount / 2]
                let dequeMedian = dequeSamples.sorted()[sampleCount / 2]
                results.append([
                    "mode": mode, "moves": count, "path_cells": 4, "iterations_per_sample": iterations,
                    "array_ns_per_iteration_samples": arraySamples,
                    "deque_ns_per_iteration_samples": dequeSamples,
                    "array_ns_per_iteration_median": arrayMedian,
                    "deque_ns_per_iteration_median": dequeMedian,
                    "deque_over_array_ratio": dequeMedian / arrayMedian,
                    "checksum": checksum,
                ])
            }
        }
        let report: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "optimization": "SwiftPM release (-O), standalone macOS executable",
            "samples_per_case": sampleCount,
            "frame_parity_cases_passed": parityCases,
            "results": results,
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
