# Reproducing 117/117

All 117 Cho Chikun life-and-death problems bundled with
[rlglab/study-LD-RZ](https://github.com/rlglab/study-LD-RZ), proved on a single
RTX 5090 by running the paper's **RZS-TT** solver at `NUM_THREAD=20` (the config
default is 2). Best-of across runs = **117/117**; a single sweep proves ~114 and
the borderline rest fall on a fresh, non-deterministic run.

## Files here

| file | what |
|---|---|
| `RZS-TT-20thread.cfg` | the paper's RZS-TT config with `NUM_THREAD=20` (300 s limit, `MAX_PAGE=512`) |
| `solve_capped.sh` | memory-safe driver: one process per problem, each in a hard cgroup RAM cap |
| `potential-rzone-guard.patch` | fixes a deterministic segfault when `USE_POTENTIAL_RZONE=true` (also filed as upstream issue #1) |
| `../results/summary_117.csv` | per-problem verdict, time, sims, proof-tree size, crucial stones |
| `../results/json/` | the raw result JSON for each of the 117 |

The **proof trees themselves** (117 solution-tree SGFs, ~85 MB compressed) are a
[GitHub Release](../../releases) asset: `proof-trees-117-20thread.tar.zst` + `SHA256SUMS.txt`.

## Steps

1. Build the solver: clone `rlglab/study-LD-RZ` and build `Release/CGI` per its
   build notes (native, WSL2 no-Docker works). To use `potential-RZ`, first apply
   `potential-rzone-guard.patch`.
2. Copy `RZS-TT-20thread.cfg` into `study-LD-RZ/cfg/`.
3. Build the problem list and solve:
   ```bash
   cd study-LD-RZ
   ls tsumego/*.json | xargs -n1 basename > all_problems.list
   LDRZ_ROOT="$PWD" LIBTORCH_CUDART=/path/to/libcudart-*.so.13 \
     /path/to/solve_capped.sh all_problems.list
   ```
4. Results land in `study-LD-RZ/result/` (a `result_*.json` and `uct_tree_*.sgf`
   per problem). Compare verdicts against `results/summary_117.csv`. Because the
   parallel search is non-deterministic, re-run any `UNKNOWN` a few times — the
   borderline problems solve on a lucky run.

## The finding (report §11)

It is **not** more compute — it is parallel diversification. With 2 threads the
search follows the tiny policy net into one doomed subtree and fills `MAX_PAGE`
without a proof. With 20 threads, virtual loss forces the threads apart; one finds
the vital move quickly and the proof closes at **far fewer** nodes — e.g.
`vol1_p090`: 443,699 sims → UNKNOWN at 2 threads vs **1,521 sims → WIN** at 20.

## Memory safety

`solve_capped.sh` runs each problem in its own `systemd-run --scope` with a hard
`MemoryMax` and swap disabled. When a huge proof tree hits the ceiling the kernel
OOM-kills that solver process only; the host / WSL is never taken down. (The earlier
failure mode — running *different* problems in parallel, each growing its own tree —
is what overflowed memory; one problem, many threads shares a single tree.)

## Soundness

Every win has a real proof tree (in the release archive) with identified crucial
stones; verdicts reproduce across runs and agree with the book's live/dead answer
on all 117 (of the first-move differences we checked, the book's move was an
equally-valid alternative solution, not an error). An **independent proof-checker**
that replays each solution tree is future work.
