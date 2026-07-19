# Solving Cho Chikun Life-and-Death Problems on a Single RTX 5090

A reproduction and **cross-generation 2×2 benchmark** (hardware × algorithm) of the relevance-zone based life-and-death solver from Shih et al. (IEEE ToG 2025, [rlglab/study-LD-RZ](https://github.com/rlglab/study-LD-RZ)), run on a single RTX 5090 + Core Ultra 9 285K.

**📄 Technical report: https://soy-tuber.github.io/tsumego-rtx5090/**

Key results:
- 2×2 matrix: RZS-TT **84/117**, RZS-PT **88/117** (paper: 68/106, 83/106)
- Same-machine TT→PT = **+4** (isolated algorithm contribution, no confound)
- **CPU-bound** (GPU ~23% idle, tiny 765k-param net) — a CPU/L2-cache generational benchmark, the mirror image of the GPU-bound [killall-go report](https://soy-tuber.github.io/killallgo-rtx5090/)
- A 28-problem **method-limited frontier**; a fixed `USE_POTENTIAL_RZONE` segfault; a negative result on unsound knowledge flags
- Frontier diagnosis: not seki-limited, not ko-rule-limited (verified experimentally), and seki-DB / RZ-reduction (arXiv:2510.00689) both turn out inapplicable on close reading — see §9

Reproduction — full credit to the original authors; this work only swaps the hardware and measures the difference.
