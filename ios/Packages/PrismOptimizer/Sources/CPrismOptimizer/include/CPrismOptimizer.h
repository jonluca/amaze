#ifndef C_PRISM_OPTIMIZER_H
#define C_PRISM_OPTIMIZER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum PrismOptimizerStatus {
    PrismOptimizerStatusOptimal = 0,
    PrismOptimizerStatusCancelled = 1,
    PrismOptimizerStatusInvalidInput = 2,
    PrismOptimizerStatusInfeasible = 3,
    PrismOptimizerStatusUnproven = 4,
    PrismOptimizerStatusInternalError = 5,
    PrismOptimizerStatusInsufficientCapacity = 6
} PrismOptimizerStatus;

typedef struct PrismOptimizerResult {
    PrismOptimizerStatus status;
    int32_t minimum_moves;
    int32_t route_count;
    /// Native lower bound after optimality proof; -1 if no proof was returned.
    double proven_lower_bound;
} PrismOptimizerResult;

/// Return nonzero to cancel. Invoked synchronously on the solving thread.
typedef int32_t (*PrismOptimizerCancelCallback)(void *context);

/// A covering route, if one exists on a supported board, has a representative
/// with at most 256 * 255 moves. This capacity always accommodates its optimum.
enum { PrismOptimizerMaximumRouteCount = 65280 };

/// Synchronously prove the minimum slide count for a board no larger than 16x16.
/// `open_cells` contains exactly width * height bytes, row-major; 0 = wall and
/// 1 = open. `start_index` indexes that array. Directions are 0 up, 1 down,
/// 2 left, 3 right. A missing or invalid hint is ignored, never used as a bound.
/// No time, search-node, or difficulty limit is imposed. Cancellation is polled
/// while preparing the model and through native LP/MIP interrupt callbacks.
///
/// Optimal is returned only after breadth-first search or the native integer
/// objective/lower bound proves the minimum and an independent route replay
/// legally covers every open cell.
/// On Optimal, route_out holds route_count directions and minimum_moves equals
/// route_count. On InsufficientCapacity, route_count reports the required size;
/// other failures return -1 for minimum_moves and 0 for route_count.
PrismOptimizerResult PrismOptimizerSolve(
    int32_t width,
    int32_t height,
    const uint8_t *open_cells,
    int32_t start_index,
    const uint8_t *hint_directions,
    int32_t hint_count,
    PrismOptimizerCancelCallback cancel,
    void *context,
    uint8_t *route_out,
    int32_t route_capacity
);

/// Prove the minimum additional slides from the player's current state.
/// `painted_cells` contains exactly width * height bytes, each 0 or 1; painted
/// cells must be open and `position_index` must already be painted. Previously
/// painted cells need not be reachable from the current position. Only the
/// unpainted cells must be covered by the returned route. An already completed
/// state returns Optimal with zero moves. Hints are replayed from this state.
/// All board, direction, proof, cancellation and output rules above apply.
PrismOptimizerResult PrismOptimizerSolveState(
    int32_t width,
    int32_t height,
    const uint8_t *open_cells,
    int32_t position_index,
    const uint8_t *painted_cells,
    const uint8_t *hint_directions,
    int32_t hint_count,
    PrismOptimizerCancelCallback cancel,
    void *context,
    uint8_t *route_out,
    int32_t route_capacity
);

#ifdef __cplusplus
}
#endif

#endif
