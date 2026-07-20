# Solving Cho Chikun Life-and-Death Problems on a Single RTX 5090

A reproduction and **cross-generation 2×2 benchmark** (hardware × algorithm) of the relevance-zone based life-and-death solver from Shih et al. (IEEE ToG 2025, [rlglab/study-LD-RZ](https://github.com/rlglab/study-LD-RZ)), run on a single RTX 5090 + Core Ultra 9 285K.

**📄 Technical report: https://soy-tuber.github.io/tsumego-rtx5090/**

Key results:
- 2×2 matrix: RZS-TT **84/117**, RZS-PT **88/117** (paper: 68/106, 83/106)
- Same-machine TT→PT = **+4** (isolated algorithm contribution, no confound)
- **CPU-bound** (GPU ~23% idle, tiny 765k-param net) — a CPU/L2-cache generational benchmark, the mirror image of the GPU-bound [killall-go report](https://soy-tuber.github.io/killallgo-rtx5090/)
- A fixed `USE_POTENTIAL_RZONE` segfault; a negative result on unsound knowledge flags
- **Update (2026-07-20, §11): 117/117 — all proved.** The "28-problem method-limited frontier" conclusion was overturned — raising `NUM_THREAD` from 2 to 20 soundly cracks the frontier via parallel-search diversification (e.g. vol1_p090: 443k sims→UNKNOWN at 2 threads vs 1,521 sims→WIN at 20). The last holdout `vol2_p262` also fell on a fresh parallel run — every one of the 28 was a borderline, parallelism-limited problem, none truly memory-bound. All runs stayed inside a cgroup memory cap; WSL never crashed.

## Artifacts

- **`recipe/`** — everything needed to reproduce: the `NUM_THREAD=20` config, a memory-safe driver (`solve_capped.sh`, one process per problem inside a cgroup RAM cap), the `USE_POTENTIAL_RZONE` fix, and [`REPRODUCE.md`](recipe/REPRODUCE.md).
- **`results/`** — [`summary_117.csv`](results/summary_117.csv) (per-problem verdict, time, sims, proof-tree size, crucial stones) and the raw result JSON for all 117.
- **[Releases](../../releases)** — `proof-trees-117-20thread.tar.zst` (~85 MB): the 117 winning solution-tree SGFs themselves, plus `SHA256SUMS.txt`.

Reproduction — full credit to the original authors; this work only swaps the hardware and measures the difference.
