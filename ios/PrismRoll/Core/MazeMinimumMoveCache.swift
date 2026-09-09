import Foundation

/// Shares exact state proofs without occupying the actor during native search.
/// A shortest route's every suffix is also shortest for its resulting paint state.
actor MazeMinimumMoveCache {
    static let shared = MazeMinimumMoveCache()

    private struct Grid: Hashable, Sendable {
        let width: Int
        let height: Int
        let openCells: Set<GridCell>

        init(_ level: MazeLevel) {
            width = level.width
            height = level.height
            openCells = level.openCells
        }
    }

    private struct State: Hashable, Sendable {
        let position: GridCell
        let painted: Set<GridCell>
    }

    private struct Key: Hashable, Sendable {
        let grid: Grid
        let state: State
    }

    private struct Proof {
        // ArraySlice shares storage with the original proof, avoiding quadratic
        // route copies when recording every suffix.
        let bufferID: UUID
        let bufferCount: Int
        let route: ArraySlice<MoveDirection>

        var result: MazeNativeOptimizer.Result {
            .optimal(moves: route.count, route: Array(route))
        }
    }

    private struct Entry {
        let grid: Grid
        var states: [State: Proof] = [:]
        var order: [State] = []
        var proofOrder: [UUID] = []
    }

    private struct Work {
        let id: UUID
        let level: MazeLevel
        var isInteractive: Bool
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<MazeNativeOptimizer.Result?, Never>]
    }

    private struct QueuedWork {
        let key: Key
        let id: UUID
    }

    private var entries: [Entry] = []
    private var pending: [Key: Work] = [:]
    private var queue: [QueuedWork] = []
    // A cancelled native solve occupies its slot until its callback actually
    // returns. Rapid swipes must not create overlapping abandoned solvers.
    private var runningWorkIDs: Set<UUID> = []
    private let workerLimit = 2
    private let solver: @Sendable (MazeLevel, GridCell, Set<GridCell>) -> MazeNativeOptimizer.Result
    private let capacity = 32
    // Bound paint-set storage as well as grid count. Long routes still retain
    // their initial proof; only the first 256 suffix states are pre-indexed.
    private let stateCapacity = 512
    // Count entire retained route buffers, including the prefixes held alive by
    // ArraySlice. This accommodates even one maximum-size native proof.
    private let routeStorageCapacity = 65_536

    init(
        solver: @escaping @Sendable (MazeLevel, GridCell, Set<GridCell>) -> MazeNativeOptimizer.Result = {
            level, position, painted in
            MazeNativeOptimizer.solve(level: level, position: position, painted: painted,
                                      isCancelled: { Task.isCancelled })
        }
    ) {
        self.solver = solver
    }

    var pendingRequestCount: Int {
        pending.values.reduce(0) { $0 + $1.waiters.count }
    }

    func minimumMoves(for level: MazeLevel) async -> Int? {
        guard !Task.isCancelled else { return nil }
        if let minimum = MazePerfectMoveCatalog.minimumMoves(for: level) {
            return Task.isCancelled ? nil : minimum
        }
        guard case let .optimal(moves, _) = await request(
            for: level, position: level.start, painted: [level.start], isInteractive: false
        ) else { return nil }
        return moves
    }

    func cachedMinimumMoves(for level: MazeLevel) -> Int? {
        if let minimum = MazePerfectMoveCatalog.minimumMoves(for: level) { return minimum }
        guard case let .optimal(moves, _) = cachedSolution(
            for: level, position: level.start, painted: [level.start]
        ) else { return nil }
        return moves
    }

    func cachedSolution(
        for level: MazeLevel, position: GridCell, painted: Set<GridCell>
    ) -> MazeNativeOptimizer.Result? {
        lookup(Key(grid: Grid(level), state: State(position: position, painted: painted)))
    }

    func solution(
        for level: MazeLevel, position: GridCell, painted: Set<GridCell>
    ) async -> MazeNativeOptimizer.Result? {
        await request(for: level, position: position, painted: painted, isInteractive: true)
    }

    private func request(
        for level: MazeLevel, position: GridCell, painted: Set<GridCell>, isInteractive: Bool
    ) async -> MazeNativeOptimizer.Result? {
        guard !Task.isCancelled else { return nil }
        let key = Key(grid: Grid(level), state: State(position: position, painted: painted))
        if let result = lookup(key) { return Task.isCancelled ? nil : result }
        let waiter = UUID()
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<MazeNativeOptimizer.Result?, Never>) in
                guard !Task.isCancelled else {
                    continuation.resume(returning: nil)
                    return
                }
                if var work = pending[key] {
                    work.waiters[waiter] = continuation
                    let promote = isInteractive && !work.isInteractive && work.task == nil
                    work.isInteractive = work.isInteractive || isInteractive
                    pending[key] = work
                    if promote {
                        queue.removeAll { $0.id == work.id }
                        enqueue(QueuedWork(key: key, id: work.id), isInteractive: true)
                    }
                    return
                }
                let workID = UUID()
                pending[key] = Work(id: workID, level: level, isInteractive: isInteractive,
                                    waiters: [waiter: continuation])
                enqueue(QueuedWork(key: key, id: workID), isInteractive: isInteractive)
                startAvailableWork()
            }
        } onCancel: {
            Task { await self.cancel(key: key, waiter: waiter) }
        }
        // Completion and onCancel may race for the actor. The requesting task
        // still observes cancellation even when completion resumed it first.
        return Task.isCancelled ? nil : result
    }

    private func enqueue(_ work: QueuedWork, isInteractive: Bool) {
        if isInteractive,
           let index = queue.firstIndex(where: { pending[$0.key]?.isInteractive == false }) {
            queue.insert(work, at: index)
        } else {
            queue.append(work)
        }
    }

    private func startAvailableWork() {
        var index = 0
        while index < queue.count {
            let queued = queue[index]
            let key = queued.key
            guard var work = pending[key], work.id == queued.id else {
                queue.remove(at: index)
                continue
            }
            // A preceding proof may have indexed this queued state as a suffix.
            // Fulfil those waiters even while unrelated native jobs fill both slots.
            if let cached = lookup(key) {
                queue.remove(at: index)
                pending.removeValue(forKey: key)
                for continuation in work.waiters.values { continuation.resume(returning: cached) }
                continue
            }
            guard runningWorkIDs.count < workerLimit else {
                index += 1
                continue
            }
            queue.remove(at: index)
            let workID = work.id
            let level = work.level
            let solver = solver
            runningWorkIDs.insert(workID)
            work.task = Task.detached(priority: .userInitiated) { [weak self] in
                let result = solver(level, key.state.position, key.state.painted)
                await self?.finish(key: key, workID: workID, result: result)
            }
            pending[key] = work
        }
    }

    private func lookup(_ key: Key) -> MazeNativeOptimizer.Result? {
        guard let index = entries.firstIndex(where: { $0.grid == key.grid }),
              let proof = entries[index].states[key.state] else { return nil }
        var entry = entries.remove(at: index)
        if let proofIndex = entry.proofOrder.firstIndex(of: proof.bufferID) {
            entry.proofOrder.remove(at: proofIndex)
            entry.proofOrder.append(proof.bufferID)
        }
        entries.append(entry)
        return proof.result
    }

    private func finish(key: Key, workID: UUID, result: MazeNativeOptimizer.Result) {
        guard runningWorkIDs.remove(workID) != nil else { return }
        defer { startAvailableWork() }
        guard let work = pending[key], work.id == workID else { return }
        pending.removeValue(forKey: key)
        var proven: MazeNativeOptimizer.Result?
        if case let .optimal(_, route) = result {
            remember(key: key, route: route)
            proven = result
        }
        for continuation in work.waiters.values { continuation.resume(returning: proven) }
    }

    private func cancel(key: Key, waiter: UUID) {
        guard var work = pending[key], let continuation = work.waiters.removeValue(forKey: waiter) else { return }
        if work.waiters.isEmpty {
            pending.removeValue(forKey: key)
            work.task?.cancel()
            queue.removeAll { $0.id == work.id }
        } else {
            pending[key] = work
        }
        continuation.resume(returning: nil)
    }

    private func remember(key: Key, route: [MoveDirection]) {
        let existing = entries.firstIndex(where: { $0.grid == key.grid })
        var entry = existing.map { entries.remove(at: $0) } ?? Entry(grid: key.grid)
        let proofID = UUID()
        entry.proofOrder.append(proofID)
        var position = key.state.position
        var painted = key.state.painted
        for offset in 0...min(route.count, 256) {
            let state = State(position: position, painted: painted)
            if entry.states[state] == nil {
                if entry.order.count == stateCapacity {
                    entry.states.removeValue(forKey: entry.order.removeFirst())
                }
                entry.order.append(state)
            }
            entry.states[state] = Proof(bufferID: proofID, bufferCount: route.count, route: route[offset...])
            guard offset < route.count else { break }
            let path = MazeSolver.path(from: position, direction: route[offset], in: key.grid.openCells)
            guard let destination = path.last else { break }
            position = destination
            painted.formUnion(path)
        }
        trimProofStorage(&entry)
        if entries.count == capacity { entries.removeFirst() }
        entries.append(entry)
    }

    private func trimProofStorage(_ entry: inout Entry) {
        var buffers: [UUID: Int] = [:]
        for proof in entry.states.values { buffers[proof.bufferID] = proof.bufferCount }
        entry.proofOrder.removeAll { buffers[$0] == nil }
        var retained = buffers.values.reduce(0, +)
        while retained > routeStorageCapacity, entry.proofOrder.count > 1 {
            let discarded = entry.proofOrder.removeFirst()
            retained -= buffers.removeValue(forKey: discarded) ?? 0
            entry.states = entry.states.filter { $0.value.bufferID != discarded }
        }
        let retainedStates = Set(entry.states.keys)
        entry.order.removeAll { !retainedStates.contains($0) }
    }

    deinit {
        for work in pending.values {
            work.task?.cancel()
            for continuation in work.waiters.values { continuation.resume(returning: nil) }
        }
    }
}
