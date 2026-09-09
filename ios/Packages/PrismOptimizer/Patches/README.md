# Reviewed upstream correctness backports

The pinned stable baseline is HiGHS 1.15.1 at
`04024d701f79feb8e2f18bc3df0dffc04ef05088`. We apply only the unchanged `highs/`
source hunks from these **merged official upstream** PRs, in the order below.
The PRs' test-source and MPS additions are excluded from the compilation patch;
the two relevant MPS regressions are exercised separately during validation.
No additional development features are imported.

| Patch | Purpose | Official merge commit |
| --- | --- | --- |
| [3177](https://github.com/ERGO-Code/HiGHS/pull/3177) | Discard redundant variable bounds before constructing cuts; prevents false zero-gap optima from invalid cuts (#3170). | `2100494d80cb77a48af9b7d7bc16e8647e9901ad` |
| [3179](https://github.com/ERGO-Code/HiGHS/pull/3179) | Preserve consistent bound substitutions across path-mixing cut rows; prevents invalid cuts that exclude the optimum (#3171). | `28339ce4b57bf8858036cbb36f4fc66d97fedd06` |
| [3181](https://github.com/ERGO-Code/HiGHS/pull/3181) | Retry a failed repair LP without presolve and recalculate row values; prevents discarding a feasible improving solution (#3180). | `ae53450f395cf0a278858868b64813ea99bb4767` |

The first two defects are not tolerance issues: upstream supplied examples
return feasible integral solutions with a zero reported gap while excluding
better solutions. Independent route replay alone would not detect that class
of library bug, so these fixes are included before relying on its lower bound.

SHA256 of the checked-in compilation patches:

```text
664ed8898303f54614ab4f919d6b73b6d9099cd369f7f0665f0d7e1865393f68  3177.patch
d51fa825370fb1e785b3083cc61816eea6b0698f701989aa43efe7ec46c9411a  3179.patch
2d3fde7ca6da73a92b4bddd27c31e2f1239b41b0f9aa3107fb1f16a36e81ebe6  3181.patch
```

For provenance, the complete official PR diffs observed on September 9, 2026
had these SHA256 values before filtering to `highs/` hunks:

```text
1bafcbf5f8c579174fbb604cf57fe58df0c789ed8554a8fe6b98ed007afc826d  3177.diff
a0590aa78eea82c20ad7b80eb6eb5a35640b8208f12a928a58b022a3180586d9  3179.diff
2d3fde7ca6da73a92b4bddd27c31e2f1239b41b0f9aa3107fb1f16a36e81ebe6  3181.diff
```

`scripts/vendor_highs.py --check` verifies the baseline archive checksum, checks
all patch checksums, applies them to a fresh temporary source tree, and checks
every vendored source/header against `VendorManifest.json`.

Run `scripts/check_upstream_regressions.sh` for the official small failure
models, with presolve enabled and disabled. Their unchanged files were fetched
from the corresponding merge commits above and have these SHA256 values:

```text
4c944ac032c88b7ada46e19630d2547453268c3a22ec82d9503a8123acc50947  issue-3170-1.mps
f6b8ab304d1c4d5b87e9f8fd5f9f80a09312053e422290fbcc0ac1145a561a90  issue-3171.mps
```
