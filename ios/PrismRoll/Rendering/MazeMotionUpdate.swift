import simd

struct MazeMotionUpdate {
    var paintedCells: [GridCell] = []
    var rotations: [SIMD2<Float>] = []
    var wallImpactDirection: SIMD2<Float>?
    var completedAt: GridCell?
}
