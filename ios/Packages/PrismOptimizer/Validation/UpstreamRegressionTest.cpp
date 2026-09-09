#include "Highs.h"

#include <cmath>
#include <cstdio>
#include <string>

// The exact reported upstream false-optimum models. Testing these is necessary
// in addition to maze route replay: an invalid cut can produce an integral,
// feasible incumbent with an incorrect zero duality gap.
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    struct Regression {
        const char* file;
        const char* presolve;
        double optimum;
    };
    const Regression cases[] = {
        {"issue-3170-1.mps", "off", -21446579.3647},
        {"issue-3170-1.mps", "on", -21446579.3647},
        {"issue-3171.mps", "on", 42215.5250005},
        {"issue-3171.mps", "off", 42215.5250005}
    };
    for (const auto& regression : cases) {
        Highs solver;
        solver.setOptionValue("output_flag", false);
        solver.setOptionValue("threads", 1);
        solver.setOptionValue("parallel", "off");
        solver.setOptionValue("random_seed", 0);
        solver.setOptionValue("mip_rel_gap", 0.0);
        solver.setOptionValue("mip_abs_gap", 0.0);
        solver.setOptionValue("presolve", regression.presolve);
        const auto path = std::string(argv[1]) + "/" + regression.file;
        if (solver.readModel(path) != HighsStatus::kOk ||
            solver.run() != HighsStatus::kOk ||
            solver.getModelStatus() != HighsModelStatus::kOptimal ||
            std::abs(solver.getObjectiveValue() - regression.optimum) > 0.001) {
            std::fprintf(stderr, "FAILED %s presolve=%s: %.10f expected %.10f\n",
                         regression.file, regression.presolve,
                         solver.getObjectiveValue(), regression.optimum);
            return 1;
        }
        std::printf("PASS %s presolve=%s: %.10f\n", regression.file,
                    regression.presolve, solver.getObjectiveValue());
    }
    return 0;
}
