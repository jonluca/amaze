#include "CPrismOptimizer.h"
#include <array>
#include <chrono>
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <vector>

struct State { int position; unsigned painted; int moves; };
constexpr int dr[4] = {-1, 1, 0, 0}, dc[4] = {0, 0, -1, 1};
State slide(unsigned open, State state, int direction) {
    int row = state.position / 3, column = state.position % 3;
    while (true) {
        int nr = row + dr[direction], nc = column + dc[direction];
        if (nr < 0 || nr >= 3 || nc < 0 || nc >= 3 || !(open & (1u << (nr * 3 + nc)))) break;
        row = nr; column = nc;
        state.position = row * 3 + column;
        state.painted |= 1u << state.position;
    }
    ++state.moves;
    return state;
}
int oracle(unsigned open, unsigned painted, int position) {
    bool seen[9 * 512] = {};
    std::vector<State> queue{{position, painted, 0}};
    seen[painted * 9 + position] = true;
    for (size_t head = 0; head < queue.size(); ++head) {
        auto state = queue[head];
        if (state.painted == open) return state.moves;
        for (int direction = 0; direction < 4; ++direction) {
            auto next = slide(open, state, direction);
            auto key = next.painted * 9 + next.position;
            if (seen[key]) continue;
            seen[key] = true;
            queue.push_back(next);
        }
    }
    return -1;
}
int main(int argc, char **argv) {
    int stride = argc > 1 ? std::atoi(argv[1]) : 1;
    uint8_t route[PrismOptimizerMaximumRouteCount];
    int total = 0, checked = 0, feasible = 0;
    const auto started = std::chrono::steady_clock::now();
    for (unsigned open = 1; open < 512; ++open) {
        std::array<uint8_t,9> cells{};
        for (int cell = 0; cell < 9; ++cell) cells[cell] = (open >> cell) & 1;
        for (unsigned painted = open; painted; painted = (painted - 1) & open) {
            std::array<uint8_t,9> paint{};
            for (int cell = 0; cell < 9; ++cell) paint[cell] = (painted >> cell) & 1;
            for (int position = 0; position < 9; ++position) {
                if (!(painted & (1u << position))) continue;
                ++total;
                if (total % stride != 0) continue;
                const auto result = PrismOptimizerSolveState(3, 3, cells.data(), position, paint.data(), nullptr, 0, nullptr, nullptr, route, sizeof(route));
                const int expected = oracle(open, painted, position);
                ++checked;
                if (expected < 0) {
                    if (result.status != PrismOptimizerStatusInfeasible) {
                        std::printf("FAIL infeasible open=%u paint=%u pos=%d status=%d\n",open,painted,position,result.status); return 1;
                    }
                    continue;
                }
                ++feasible;
                if (result.status != PrismOptimizerStatusOptimal || result.minimum_moves != expected || result.route_count != expected || std::ceil(result.proven_lower_bound - 1e-6) != expected) {
                    std::printf("FAIL optimum open=%u paint=%u pos=%d status=%d expected=%d actual=%d bound=%g\n",open,painted,position,result.status,expected,result.minimum_moves,result.proven_lower_bound); return 1;
                }
                State state{position, painted, 0};
                for (int index = 0; index < result.route_count; ++index) {
                    if (route[index] >= 4 || state.painted == open) return 2;
                    const auto next = slide(open, state, route[index]);
                    if (next.position == state.position) return 3;
                    state = next;
                }
                if (state.painted != open) return 4;
            }
        }
    }
    std::array<uint8_t,9> cells{1,1,1,1,1,1,1,1,1}, painted{1,0,0,0,0,0,0,0,0};
    auto result = PrismOptimizerSolveState(3,3,cells.data(),0,painted.data(),nullptr,0,[](void*) -> int32_t {return 1;},nullptr,route,sizeof(route));
    if (result.status != PrismOptimizerStatusCancelled) return 5;
    painted[0] = 0;
    result = PrismOptimizerSolveState(3,3,cells.data(),0,painted.data(),nullptr,0,nullptr,nullptr,route,sizeof(route));
    if (result.status != PrismOptimizerStatusInvalidInput) return 6;
    painted[0] = 2;
    result = PrismOptimizerSolveState(3,3,cells.data(),0,painted.data(),nullptr,0,nullptr,nullptr,route,sizeof(route));
    if (result.status != PrismOptimizerStatusInvalidInput) return 7;
    result = PrismOptimizerSolveState(3,3,cells.data(),0,nullptr,nullptr,0,nullptr,nullptr,route,sizeof(route));
    if (result.status != PrismOptimizerStatusInvalidInput) return 8;
    uint8_t line[] = {1,1,1}, initial[] = {1,0,0};
    result = PrismOptimizerSolveState(3,1,line,0,initial,nullptr,0,nullptr,nullptr,nullptr,0);
    if (result.status != PrismOptimizerStatusInsufficientCapacity || result.route_count != 1 || result.minimum_moves != -1) return 9;
    const auto elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - started).count();
    std::printf("PASS %d arbitrary current states (%d feasible, %d infeasible) from %d possibilities; %.3fs; cancellation, invalid state, capacity passed\n", checked, feasible, checked-feasible, total, elapsed);
}
