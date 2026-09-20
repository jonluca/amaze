@MainActor
final class AttributionSessionReadiness {
    private var generation = 0

    func invalidate() { generation += 1 }

    func delivery(_ ready: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        let scheduledGeneration = generation
        return { [weak self] in
            guard let self, self.generation == scheduledGeneration else { return }
            ready()
        }
    }
}
