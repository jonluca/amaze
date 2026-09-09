#include "CPrismOptimizer.h"

#include "Highs.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <utility>
#include <vector>

namespace {

constexpr double kProofTolerance = 1e-6;
constexpr std::array<int, 4> kRowDelta = {-1, 1, 0, 0};
constexpr std::array<int, 4> kColumnDelta = {0, 0, -1, 1};

struct Cancelled {};

struct Cancellation {
    PrismOptimizerCancelCallback callback;
    void *context;
    bool interrupted = false;

    bool check() {
        interrupted = interrupted || (callback && callback(context) != 0);
        return interrupted;
    }

    void poll() {
        if (check()) throw Cancelled{};
    }
};

struct Edge {
    int source;
    int destination;
    uint8_t direction;
    std::vector<int> painted;
};

struct Graph {
    int width;
    int height;
    int start;
    int openCount = 0;
    std::vector<uint8_t> open;
    std::vector<uint8_t> initiallyPainted;
    int remainingCount = 0;
    std::vector<int> nodes;
    std::vector<Edge> edges;
    std::vector<std::vector<int>> outgoing;
    std::vector<std::vector<int>> incoming;
    std::vector<std::vector<int>> requirements;
};

PrismOptimizerResult failure(PrismOptimizerStatus status) {
    return {status, -1, 0, -1};
}

Graph makeGraph(int width, int height, const uint8_t *open, int start,
                const uint8_t *initiallyPainted,
                Cancellation &cancellation) {
    Graph graph{};
    graph.width = width;
    graph.height = height;
    graph.start = start;
    graph.open.assign(open, open + width * height);
    graph.openCount = static_cast<int>(std::count(graph.open.begin(), graph.open.end(), 1));
    graph.initiallyPainted.assign(width * height, 0);
    if (initiallyPainted)
        std::copy(initiallyPainted, initiallyPainted + width * height, graph.initiallyPainted.begin());
    else
        graph.initiallyPainted[start] = 1;
    graph.remainingCount = graph.openCount - static_cast<int>(
        std::count(graph.initiallyPainted.begin(), graph.initiallyPainted.end(), 1));
    graph.nodes.push_back(start);
    std::vector<int> index(width * height, -1);
    index[start] = 0;

    // Only wall-stop positions (and the supplied start) are movement states.
    for (size_t source = 0; source < graph.nodes.size(); ++source) {
        cancellation.poll();
        const int sourceCell = graph.nodes[source];
        for (uint8_t direction = 0; direction < 4; ++direction) {
            int row = sourceCell / width;
            int column = sourceCell % width;
            std::vector<int> painted;
            while (true) {
                const int nextRow = row + kRowDelta[direction];
                const int nextColumn = column + kColumnDelta[direction];
                if (nextRow < 0 || nextRow >= height || nextColumn < 0 || nextColumn >= width)
                    break;
                const int nextCell = nextRow * width + nextColumn;
                if (!graph.open[nextCell]) break;
                row = nextRow;
                column = nextColumn;
                painted.push_back(nextCell);
            }
            if (painted.empty()) continue;
            const int destination = painted.back();
            if (index[destination] < 0) {
                index[destination] = static_cast<int>(graph.nodes.size());
                graph.nodes.push_back(destination);
            }
            graph.edges.push_back({static_cast<int>(source), index[destination], direction,
                                   std::move(painted)});
        }
    }

    graph.outgoing.resize(graph.nodes.size());
    graph.incoming.resize(graph.nodes.size());
    std::vector<std::vector<int>> coveringEdges(width * height);
    for (size_t edge = 0; edge < graph.edges.size(); ++edge) {
        const auto &value = graph.edges[edge];
        graph.outgoing[value.source].push_back(static_cast<int>(edge));
        graph.incoming[value.destination].push_back(static_cast<int>(edge));
        for (int cell : value.painted) coveringEdges[cell].push_back(static_cast<int>(edge));
    }

    for (int cell = 0; cell < width * height; ++cell) {
        if (graph.open[cell] && !graph.initiallyPainted[cell])
            graph.requirements.push_back(coveringEdges[cell]);
    }
    // If every edge painting A also paints B, satisfying A satisfies B. Keep
    // only inclusion-minimal requirements. This changes no feasible route.
    std::sort(graph.requirements.begin(), graph.requirements.end(),
              [](const auto &left, const auto &right) {
                  return left.size() == right.size() ? left < right : left.size() < right.size();
              });
    std::vector<std::vector<int>> necessary;
    for (const auto &requirement : graph.requirements) {
        cancellation.poll();
        const bool redundant = std::any_of(necessary.begin(), necessary.end(),
            [&requirement](const auto &kept) {
                return std::includes(requirement.begin(), requirement.end(),
                                     kept.begin(), kept.end());
            });
        if (!redundant) necessary.push_back(requirement);
    }
    graph.requirements = std::move(necessary);
    return graph;
}

// Normalize harmless blocked swipes and stop at the actual completion. Never
// trust a supplied route length: only a replayed, fully covering route is an UB.
std::vector<int> verifiedHint(const Graph &graph, const uint8_t *directions,
                              int count, Cancellation &cancellation) {
    if (!directions || count <= 0) return {};
    auto painted = graph.initiallyPainted;
    int remaining = graph.remainingCount;
    int position = 0;
    std::vector<int> route;
    for (int index = 0; index < count && remaining > 0; ++index) {
        cancellation.poll();
        if (directions[index] > 3) return {};
        for (int edge : graph.outgoing[position]) {
            const auto &value = graph.edges[edge];
            if (value.direction != directions[index]) continue;
            route.push_back(edge);
            for (int cell : value.painted) {
                if (!painted[cell]) {
                    painted[cell] = 1;
                    --remaining;
                }
            }
            position = value.destination;
            break;
        }
    }
    return remaining == 0 ? route : std::vector<int>{};
}

// Paint history matters only through the inclusion-minimal requirements. For
// small remaining problems, a compact breadth-first search proves the shortest
// route directly, avoiding LP/MIP setup altogether. The allocation cap selects
// an algorithm; it never limits the exact solver, which falls through to MIP.
bool solveSmallGraph(const Graph &graph, std::vector<int> &route,
                     bool &infeasible, Cancellation &cancellation) {
    constexpr uint32_t kMaximumStates = 1u << 20;
    const auto requirementCount = graph.requirements.size();
    const uint32_t nodeCount = static_cast<uint32_t>(graph.nodes.size());
    if (requirementCount >= 20 || (uint64_t{1} << requirementCount) * nodeCount > kMaximumStates)
        return false;
    const uint32_t complete = (uint32_t{1} << requirementCount) - 1;
    std::vector<uint32_t> edgeMasks(graph.edges.size(), 0);
    for (size_t requirement = 0; requirement < requirementCount; ++requirement) {
        for (int edge : graph.requirements[requirement])
            edgeMasks[edge] |= uint32_t{1} << requirement;
    }
    const auto stateCount = (complete + 1) * nodeCount;
    std::vector<int> parent(stateCount, -1);
    std::vector<int> parentEdge(stateCount, -1);
    std::vector<uint32_t> queue{0};
    parent[0] = 0;
    for (size_t head = 0; head < queue.size(); ++head) {
        if ((head & 255) == 0) cancellation.poll();
        const uint32_t state = queue[head];
        const uint32_t mask = state / nodeCount;
        const uint32_t node = state % nodeCount;
        for (int edge : graph.outgoing[node]) {
            const uint32_t nextMask = mask | edgeMasks[edge];
            const uint32_t next = nextMask * nodeCount + graph.edges[edge].destination;
            if (parent[next] != -1) continue;
            parent[next] = static_cast<int>(state);
            parentEdge[next] = edge;
            if (nextMask == complete) {
                for (uint32_t cursor = next; cursor != 0; cursor = parent[cursor])
                    route.push_back(parentEdge[cursor]);
                std::reverse(route.begin(), route.end());
                cancellation.poll();
                return true;
            }
            queue.push_back(next);
        }
    }
    infeasible = true;
    return true;
}

// Repeatedly take a shortest path that paints a new cell. This cheaply supplies
// a feasible incumbent and substantially tightens the commodity-flow bounds.
// Directed mazes can trap this heuristic, so a failed attempt supplies no bound.
std::vector<int> greedyRoute(const Graph &graph, int directionOffset,
                             Cancellation &cancellation) {
    auto painted = graph.initiallyPainted;
    int remaining = graph.remainingCount;
    int position = 0;
    std::vector<int> route;
    while (remaining > 0) {
        cancellation.poll();
        std::vector<int> parentEdge(graph.nodes.size(), -1);
        std::vector<int> queue{position};
        parentEdge[position] = -2;
        int paintingEdge = -1;
        for (size_t head = 0; head < queue.size() && paintingEdge < 0; ++head) {
            const int node = queue[head];
            // Rotating tie breaks cheaply diversifies the incumbent candidates.
            for (int offset = 0; offset < 4 && paintingEdge < 0; ++offset) {
                const int direction = (offset + directionOffset) % 4;
                for (int edge : graph.outgoing[node]) {
                    const auto &value = graph.edges[edge];
                    if (value.direction != direction) continue;
                    if (std::any_of(value.painted.begin(), value.painted.end(),
                                    [&painted](int cell) { return !painted[cell]; })) {
                        paintingEdge = edge;
                        break;
                    }
                    if (parentEdge[value.destination] == -1) {
                        parentEdge[value.destination] = edge;
                        queue.push_back(value.destination);
                    }
                }
            }
        }
        if (paintingEdge < 0) return {};
        std::vector<int> segment{paintingEdge};
        for (int node = graph.edges[paintingEdge].source; node != position;) {
            const int edge = parentEdge[node];
            segment.push_back(edge);
            node = graph.edges[edge].source;
        }
        for (auto iterator = segment.rbegin(); iterator != segment.rend(); ++iterator) {
            const auto &value = graph.edges[*iterator];
            route.push_back(*iterator);
            position = value.destination;
            for (int cell : value.painted) {
                if (!painted[cell]) {
                    painted[cell] = 1;
                    --remaining;
                }
            }
        }
    }
    return route;
}

struct MatrixBuilder {
    HighsLp lp;

    explicit MatrixBuilder(int columns) {
        lp.num_col_ = columns;
        lp.num_row_ = 0;
        lp.sense_ = ObjSense::kMinimize;
        lp.a_matrix_.format_ = MatrixFormat::kRowwise;
        lp.a_matrix_.start_.assign(1, 0);
    }

    void row(const std::vector<std::pair<int, double>> &terms, double lower, double upper) {
        // Several contributions can target the same variable (flow balance),
        // so consolidate before passing a sparse matrix to HiGHS.
        auto sorted = terms;
        std::sort(sorted.begin(), sorted.end(), [](const auto &left, const auto &right) {
            return left.first < right.first;
        });
        for (size_t index = 0; index < sorted.size();) {
            const int column = sorted[index].first;
            double value = 0;
            do { value += sorted[index++].second; }
            while (index < sorted.size() && sorted[index].first == column);
            if (value == 0) continue;
            lp.a_matrix_.index_.push_back(column);
            lp.a_matrix_.value_.push_back(value);
        }
        lp.a_matrix_.start_.push_back(static_cast<HighsInt>(lp.a_matrix_.index_.size()));
        lp.row_lower_.push_back(lower);
        lp.row_upper_.push_back(upper);
        ++lp.num_row_;
    }
};

HighsLp makeModel(const Graph &graph, int upperBound, Cancellation &cancellation) {
    const int edges = static_cast<int>(graph.edges.size());
    MatrixBuilder model(2 * edges);
    model.lp.col_cost_.assign(2 * edges, 0);
    model.lp.col_lower_.assign(2 * edges, 0);
    model.lp.col_upper_.assign(2 * edges, upperBound);
    model.lp.integrality_.assign(2 * edges, HighsVarType::kContinuous);
    for (int edge = 0; edge < edges; ++edge) {
        model.lp.col_cost_[edge] = 1;
        model.lp.integrality_[edge] = HighsVarType::kInteger;
    }

    for (const auto &requirement : graph.requirements) {
        cancellation.poll();
        std::vector<std::pair<int, double>> terms;
        for (int edge : requirement) terms.emplace_back(edge, 1);
        model.row(terms, 1, kHighsInf);
    }
    for (size_t node = 0; node < graph.nodes.size(); ++node) {
        std::vector<std::pair<int, double>> terms;
        for (int edge : graph.outgoing[node]) terms.emplace_back(edge, 1);
        for (int edge : graph.incoming[node]) terms.emplace_back(edge, -1);
        // An Euler walk starts at node zero and may finish at any node.
        model.row(terms, node == 0 ? 0 : -1, node == 0 ? 1 : 0);
    }
    std::vector<std::pair<int, double>> total;
    for (int edge = 0; edge < edges; ++edge) total.emplace_back(edge, 1);
    model.row(total, 0, upperBound);

    // A commodity from the start delivers one unit to every selected departure
    // elsewhere. This excludes disconnected subtours without enumerating them.
    for (size_t node = 1; node < graph.nodes.size(); ++node) {
        cancellation.poll();
        std::vector<std::pair<int, double>> terms;
        for (int edge : graph.incoming[node]) terms.emplace_back(edges + edge, 1);
        for (int edge : graph.outgoing[node]) {
            terms.emplace_back(edges + edge, -1);
            terms.emplace_back(edge, -1);
        }
        model.row(terms, 0, 0);
    }
    for (int edge = 0; edge < edges; ++edge) {
        model.row({{edges + edge, 1}, {edge, -static_cast<double>(upperBound)}}, -kHighsInf, 0);
    }
    model.lp.setMatrixDimensions();
    return std::move(model.lp);
}

HighsSolution makeWarmStart(const Graph &graph, const std::vector<int> &route) {
    const int edgeCount = static_cast<int>(graph.edges.size());
    HighsSolution solution;
    solution.col_value.assign(2 * edgeCount, 0);
    for (int edge : route) ++solution.col_value[edge];
    // Route support is reachable from zero. Deliver each node's demand along
    // a directed spanning tree, so every commodity value is at most route.size.
    std::vector<int> parentEdge(graph.nodes.size(), -1);
    std::vector<int> traversal{0};
    parentEdge[0] = -2;
    for (size_t index = 0; index < traversal.size(); ++index) {
        for (int edge : graph.outgoing[traversal[index]]) {
            if (solution.col_value[edge] == 0) continue;
            const int destination = graph.edges[edge].destination;
            if (parentEdge[destination] != -1) continue;
            parentEdge[destination] = edge;
            traversal.push_back(destination);
        }
    }
    std::vector<int> demand(graph.nodes.size(), 0);
    for (int edge : route) {
        if (graph.edges[edge].source != 0) ++demand[graph.edges[edge].source];
    }
    for (auto iterator = traversal.rbegin(); iterator != traversal.rend(); ++iterator) {
        const int node = *iterator;
        if (node == 0) continue;
        const int edge = parentEdge[node];
        solution.col_value[edgeCount + edge] = demand[node];
        demand[graph.edges[edge].source] += demand[node];
    }
    solution.value_valid = true;
    return solution;
}

bool reconstruct(const Graph &graph, const std::vector<double> &solution, int upperBound,
                 std::vector<uint8_t> &directions, Cancellation &cancellation) {
    if (solution.size() < graph.edges.size()) return false;
    std::vector<int> counts;
    int total = 0;
    for (size_t edge = 0; edge < graph.edges.size(); ++edge) {
        const double value = solution[edge];
        if (!std::isfinite(value) || value < -kProofTolerance || value > upperBound + kProofTolerance)
            return false;
        const int rounded = static_cast<int>(std::round(value));
        if (std::abs(value - rounded) > kProofTolerance) return false;
        total += rounded;
        if (total > upperBound) return false;
        counts.push_back(rounded);
    }

    // Hierholzer reconstruction retains multiplicities without expanding all
    // adjacency lists. Replay below also rejects any disconnected solution.
    std::vector<size_t> next(graph.nodes.size(), 0);
    std::vector<std::pair<int, int>> stack{{0, -1}};
    std::vector<int> reverseRoute;
    while (!stack.empty()) {
        cancellation.poll();
        const int node = stack.back().first;
        const auto &outgoing = graph.outgoing[node];
        while (next[node] < outgoing.size() && counts[outgoing[next[node]]] == 0) ++next[node];
        if (next[node] == outgoing.size()) {
            if (stack.back().second >= 0) reverseRoute.push_back(stack.back().second);
            stack.pop_back();
        } else {
            const int edge = outgoing[next[node]];
            --counts[edge];
            stack.emplace_back(graph.edges[edge].destination, edge);
        }
    }
    if (static_cast<int>(reverseRoute.size()) != total) return false;

    int position = 0;
    auto painted = graph.initiallyPainted;
    for (auto iterator = reverseRoute.rbegin(); iterator != reverseRoute.rend(); ++iterator) {
        cancellation.poll();
        const auto &edge = graph.edges[*iterator];
        if (edge.source != position) return false;
        position = edge.destination;
        for (int cell : edge.painted) painted[cell] = 1;
        directions.push_back(edge.direction);
    }
    return painted == graph.open;
}

PrismOptimizerResult solve(int width, int height, const uint8_t *open, int start,
                           const uint8_t *initiallyPainted,
                           const uint8_t *hint, int hintCount, Cancellation &cancellation,
                           uint8_t *output, int capacity) {
    if (width < 1 || height < 1 || width > 16 || height > 16 || !open ||
        start < 0 || start >= width * height || hintCount < 0 ||
        (hintCount > 0 && !hint) || capacity < 0 || (capacity > 0 && !output))
        return failure(PrismOptimizerStatusInvalidInput);
    for (int cell = 0; cell < width * height; ++cell) {
        if (open[cell] > 1 || (initiallyPainted && initiallyPainted[cell] > open[cell]))
            return failure(PrismOptimizerStatusInvalidInput);
    }
    if (!open[start] || (initiallyPainted && !initiallyPainted[start]))
        return failure(PrismOptimizerStatusInvalidInput);
    cancellation.poll();
    const Graph graph = makeGraph(width, height, open, start, initiallyPainted, cancellation);
    if (graph.remainingCount == 0) return {PrismOptimizerStatusOptimal, 0, 0, 0};
    if (graph.requirements.empty() || graph.requirements.front().empty())
        return failure(PrismOptimizerStatusInfeasible);

    std::vector<int> smallRoute;
    bool smallInfeasible = false;
    if (solveSmallGraph(graph, smallRoute, smallInfeasible, cancellation)) {
        if (smallInfeasible) return failure(PrismOptimizerStatusInfeasible);
        std::vector<uint8_t> directions;
        for (int edge : smallRoute) directions.push_back(graph.edges[edge].direction);
        if (verifiedHint(graph, directions.data(), static_cast<int>(directions.size()),
                         cancellation) != smallRoute)
            return failure(PrismOptimizerStatusUnproven);
        const int minimum = static_cast<int>(directions.size());
        cancellation.poll();
        if (capacity < minimum)
            return {PrismOptimizerStatusInsufficientCapacity, -1, minimum, static_cast<double>(minimum)};
        std::copy(directions.begin(), directions.end(), output);
        return {PrismOptimizerStatusOptimal, minimum, minimum, static_cast<double>(minimum)};
    }

    auto route = verifiedHint(graph, hint, hintCount, cancellation);
    for (int offset = 0; offset < 4; ++offset) {
        auto candidate = greedyRoute(graph, offset, cancellation);
        if (!candidate.empty() && (route.empty() || candidate.size() < route.size()))
            route = std::move(candidate);
    }
    // Without a valid hint, a shortest covering walk has at most R first-paint
    // events. Between consecutive events, delete repeated-position loops (they
    // paint nothing new): each segment then has at most N edges. N*R is a
    // finite, valid bound on some optimum, even on non-strongly-connected graphs.
    const int universalBound = static_cast<int>(graph.nodes.size()) * graph.remainingCount;
    const int upperBound = route.empty() ? universalBound
        : std::min(universalBound, static_cast<int>(route.size()));

    Highs highs;
    const auto option = [&highs](const char *name, auto value) {
        return highs.setOptionValue(name, value) == HighsStatus::kOk;
    };
    if (!option("output_flag", false) || !option("log_to_console", false) ||
        !option("threads", 1) || !option("parallel", "off") ||
        !option("time_limit", kHighsInf) || !option("mip_max_nodes", kHighsIInf) ||
        !option("mip_rel_gap", 0.0) || !option("mip_abs_gap", 0.0) ||
        !option("mip_feasibility_tolerance", 1e-8) ||
        !option("primal_feasibility_tolerance", 1e-8) ||
        !option("dual_feasibility_tolerance", 1e-8))
        return failure(PrismOptimizerStatusInternalError);

    const HighsCallbackFunctionType callback = [](int, const std::string &,
        const HighsCallbackOutput *, HighsCallbackInput *input, void *context) {
        auto &token = *static_cast<Cancellation *>(context);
        if (input && token.check()) input->user_interrupt = true;
    };
    if (highs.setCallback(callback, &cancellation) != HighsStatus::kOk)
        return failure(PrismOptimizerStatusInternalError);
    for (const int callbackType : {kCallbackSimplexInterrupt, kCallbackIpmInterrupt, kCallbackMipInterrupt}) {
        if (highs.startCallback(callbackType) != HighsStatus::kOk)
            return failure(PrismOptimizerStatusInternalError);
    }

    cancellation.poll();
    if (highs.passModel(makeModel(graph, upperBound, cancellation)) != HighsStatus::kOk)
        return failure(PrismOptimizerStatusInternalError);
    if (!route.empty() && static_cast<int>(route.size()) <= upperBound &&
        highs.setSolution(makeWarmStart(graph, route)) == HighsStatus::kError)
        return failure(PrismOptimizerStatusInternalError);
    cancellation.poll();
    const auto runStatus = highs.run();
    cancellation.poll();
    if (runStatus == HighsStatus::kError) return failure(PrismOptimizerStatusInternalError);
    if (highs.getModelStatus() == HighsModelStatus::kInfeasible)
        return failure(PrismOptimizerStatusInfeasible);
    if (highs.getModelStatus() != HighsModelStatus::kOptimal)
        return failure(PrismOptimizerStatusUnproven);

    std::vector<uint8_t> directions;
    if (!highs.getSolution().value_valid ||
        !reconstruct(graph, highs.getSolution().col_value, upperBound, directions, cancellation))
        return failure(PrismOptimizerStatusUnproven);
    const int minimum = static_cast<int>(directions.size());
    const auto &info = highs.getInfo();
    const double bound = info.mip_dual_bound;
    if (!std::isfinite(info.objective_function_value) || !std::isfinite(bound) ||
        std::abs(info.objective_function_value - minimum) > kProofTolerance ||
        bound > minimum + kProofTolerance ||
        std::ceil(bound - kProofTolerance) != minimum)
        return failure(PrismOptimizerStatusUnproven);
    cancellation.poll();
    if (capacity < minimum) return {PrismOptimizerStatusInsufficientCapacity, -1, minimum, bound};
    if (!directions.empty()) std::copy(directions.begin(), directions.end(), output);
    return {PrismOptimizerStatusOptimal, minimum, minimum, bound};
}

} // namespace

extern "C" PrismOptimizerResult PrismOptimizerSolve(
    int32_t width, int32_t height, const uint8_t *open_cells, int32_t start_index,
    const uint8_t *hint_directions, int32_t hint_count,
    PrismOptimizerCancelCallback cancel, void *context,
    uint8_t *route_out, int32_t route_capacity
) {
    try {
        Cancellation cancellation{cancel, context};
        return solve(width, height, open_cells, start_index, nullptr, hint_directions, hint_count,
                     cancellation, route_out, route_capacity);
    } catch (const Cancelled &) {
        return failure(PrismOptimizerStatusCancelled);
    } catch (...) {
        // Includes allocation failures. No C++ exception may cross into Swift.
        return failure(PrismOptimizerStatusInternalError);
    }
}

extern "C" PrismOptimizerResult PrismOptimizerSolveState(
    int32_t width, int32_t height, const uint8_t *open_cells, int32_t position_index,
    const uint8_t *painted_cells, const uint8_t *hint_directions, int32_t hint_count,
    PrismOptimizerCancelCallback cancel, void *context,
    uint8_t *route_out, int32_t route_capacity
) {
    if (!painted_cells) return failure(PrismOptimizerStatusInvalidInput);
    try {
        Cancellation cancellation{cancel, context};
        return solve(width, height, open_cells, position_index, painted_cells,
                     hint_directions, hint_count, cancellation, route_out, route_capacity);
    } catch (const Cancelled &) {
        return failure(PrismOptimizerStatusCancelled);
    } catch (...) {
        return failure(PrismOptimizerStatusInternalError);
    }
}
