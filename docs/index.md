# Solving Cho Chikun Life-and-Death Problems on a Single RTX 5090
## A Cross-Generation 2×2 Benchmark (Hardware × Algorithm) of the Relevance-Zone L&D Solver — Technical Report v0.1

**Date**: 2026-07-19 / **Status**: v0.1 public technical report(英訳版は準備中)

Companion report (same RTX 5090, the *opposite* bottleneck): [Solving 7×7 Killall-Go Opening JA](https://soy-tuber.github.io/killallgo-rtx5090/).

---

### Abstract (EN)

We reproduce the relevance-zone (RZ) based life-and-death solver of Shih et al. (IEEE ToG 2025, *A Study of Solving Life-and-Death Problems in Go Using Relevance-Zone Based Solvers*) on a single consumer machine (RTX 5090 / Core Ultra 9 285K, WSL2), and sweep the 117 bundled Cho Chikun problems under the paper's own 5-minute limit. Holding the code, problems, and configuration fixed, we vary only (a) the hardware generation and (b) the algorithm (RZS-TT vs RZS-PT), yielding a clean **2×2 matrix** that separates the hardware contribution from the algorithm contribution with no cross-machine confound. On the newer machine the proved count rises to **84/117 (RZS-TT)** and **88/117 (RZS-PT)**, versus the paper's reported **68/106** and **83/106**. The same-machine TT→PT delta (**+4**, with 5 gains and 1 regression) isolates the pattern-table contribution. Crucially, the neural network is tiny (765,523 parameters) and the GPU sits at **~23% utilization**: this is a **CPU-generation** benchmark (Haswell 2014 → Arrow Lake 2024, with a **12× larger per-core L2 cache**), not a GPU one — the mirror image of our GPU-bound killall-go report. We additionally (i) find and fix a deterministic segfault in the `USE_POTENTIAL_RZONE` code path (upstream issue + patch), (ii) document that the `USE_EARLY_LIFE`/`USE_PATTERN_EYE` knowledge flags are **unsound** for proof purposes (they emit 0-simulation false positives), and (iii) establish a 28-problem **method-limited frontier** that no amount of extra time or the current RZ machinery cracks.

### 要旨(JP)

RZ(relevance-zone)ベースの死活ソルバ(Shih et al., IEEE ToG 2025)を単一のRTX 5090 + Core Ultra 9 285K(WSL2)で再現し、同梱の趙治勲事典117問を論文条件(5分制限)でスイープした。コード・問題・設定を固定し、(a)ハード世代と(b)アルゴリズム(RZS-TT/RZS-PT)だけを変えることで、**ハード寄与とアルゴリズム寄与を交絡なしで分離する2×2行列**を得た。証明数は新機で**84/117(TT)・88/117(PT)**(論文報告値68/106・83/106)。同一マシン上のTT→PT差(**+4**、救済5・回帰1)がパターンテーブルの純寄与。NNは極小(765,523params)でGPU実利用率は**約23%**——本研究は**CPU世代ベンチ**(Haswell 2014→Arrow Lake 2024、**L2キャッシュ12倍**)であり、GPU律速のkillall-go編とは律速点が逆。加えて(i)`USE_POTENTIAL_RZONE`経路の決定的segfaultを特定・修正(upstream issue+patch)、(ii)`USE_EARLY_LIFE`/`USE_PATTERN_EYE`知識フラグが証明目的には**不健全**(sims=0の偽陽性)であることを実証、(iii)追加時間でも現行RZ手法でも崩せない**手法律速の28問フロンティア**を確定した。

---

## 1. 背景

- 対象システム: [rlglab/study-LD-RZ](https://github.com/rlglab/study-LD-RZ)(IEEE ToG 2025)。19路局所の死活問題を、Relevance-Zone(RZ)で探索領域を局所化するAND/OR証明探索で解く。ソルバはニューラルネット(FTLネット、5ブロック×64)で誘導される。
- 2つの構成: **RZS-TT**(盤面置換表)と **RZS-PT**(RZone置換表＝解いたRZの永続再利用)。同梱cfgそのまま。
- 論文の参照環境はGTX 1080Ti + Xeon世代。本走行の位置づけ: (a)忠実な再現、(b)世代間実測、(c)ハード×アルゴリズムの2×2分離。

> **killall-goとの違い(重要)**: 姉妹研究のkillall-goソルバは大きめのPCN netでGPU律速だったため、per-slot 2.01×の**クリーンなGPU世代比**が出た。本死活ソルバはNNが極小でGPUがほぼ遊休。よって同じ5090上でも、こちらは**CPU律速**。同一ハードで律速点が逆になる好対照。

## 2. 実験設定

| 項目 | 本走行 | 論文参照(報告値) |
|---|---|---|
| GPU | RTX 5090 32GB(Blackwell, 2025) | GTX 1080Ti(Pascal, 2017) |
| **CPU** | Core Ultra 9 285K(**Arrow Lake, 2024**, 24C) | Xeon E5-2683 v3(**Haswell, 2014**, 14C/28T) |
| **L2 / コア** | **3 MB** | **256 KB**(≈12×) |
| L3(共有) | 36 MB | 35 MB(ほぼ据置) |
| 探索スレッド | NUM_THREAD=2 | 同cfg |
| 制限 | 300 s / 問 | 300 s / 問 |
| NN | FTL 5B×64, 765,523 params(3.66 MB) | 同一 |
| ソフトウェア | libtorch 2.11.0+cu130 / CUDA 13.2 / gcc 13.3 / WSL2 | 当時の環境 |
| 走行 | 1列直列(NW=1)、3走行(pass1 / ボーダー再走 / pass2) | — |

母数が異なる(本117問 vs 論文106問)ため、数の直接比較でなく率で読む。

## 3. 再現性の検証(3走行方式)

証明探索は並列非決定なので、全117問を **pass1 → ボーダー再走(未解＋250s超を単独全リソースで) → pass2** の3走行で回し、「少なくとも1回証明」を合算した。RZS-TTでの走行間分散: pass1=80、pass2=79、両passで証明77問、**片方のみ5問**(vol2 p138/p142/p152/p166/p372=300s直下の時刻シード依存の境界問題)。分散は実在するが小さい。

## 4. 結果: 2×2マトリクス

| | 1080Ti + Xeon(論文) | RTX 5090 + 285K(本機) |
|---|---|---|
| **RZS-TT** | 68 / 106 (64%) | **84 / 117 (72%)** |
| **RZS-PT** | 83 / 106 (78%) | **88 / 117 (75%)** |

- **ハード寄与(列方向)**: 同一アルゴリズムで基盤を替えると境界が前進(TT 64%→72%、PT 78%→75%)。ただし§5のとおりGPUでなく主にCPU世代の寄与。
- **アルゴリズム寄与(行方向、交絡なし)**: 同一マシンで **TT 84 → PT 88(+4)**。内訳は純加算でなく**トレード**: PTが新規救済5問(vol2 p146/p253/p257/p334/p340=過去RZ再利用が効く型)、PTが取りこぼし1問(vol2 p129=RZone TTが常に優位でない証拠)。
- **相補性**: TT∪PT = **89/117**。片方だけが解く問題があり、2手法は相補的(PTは一方的上位互換ではない)。運用上は和をとるのが最強。

## 5. 律速はCPU、特にL2キャッシュ(実測)

走行中の実測: **GPU sm利用率 21–27%で安定**(mem-util 0%、VRAM 644 MB、143 W/575 W)、CGIは190% CPU(NUM_THREAD=2)、load ≈ 2.0。GPUはほぼ遊休で、律速は**CPU側の証明探索**(RZ展開・パターンマッチ・置換表アクセス＝ランダムなポインタ追跡＝キャッシュ遅延律速)。

`sysfs`で確認した実機キャッシュは **L2 3 MB/コア**(Xeon Haswellの256 KB/コアに対し**約12×**)。一方 **L3は据置(36 vs 35 MB)**。増えたのは私的L2だけで、置換表の hot working set が高速L2に収まりやすくなったことが、境界前進の有力な寄与と考える。ただし**WSL2でハードウェアPMU(perf)が使えず、L2ミス率の直接測定はできていない**——size contrast と access pattern に基づく**仮説**であり、clock・IPC・DDR5遅延の寄与とも交絡する。よって本ベンチは「GPU世代比」ではなく**リグ世代比(CPU支配)**と読むべきである。

## 6. 手法律速のフロンティア(28問)

TT・PT両方が全走行で未解の問題は **28問**(vol1: p090/p098/p150の3、vol2: 25問、事典の最難問帯に集中)。これらは**時間律速でなく手法律速**であることを次で確認した:

- **potential-RZ投入**: §7で修正した健全な potential-RZ を28問に投入 → **0/28**(全問300s timeout、偽陽性0)。RZ枝刈りの強化では崩れない。
- **時間延長は無効**: 300sで既に60万sims超を費やして閉じない(例 vol2_p124=639,552 sims→UNKNOWN)。証明コストが深さに対し急伸する領域で、延長のコスパは悪い。

→ この28問は、**セキ(双活)DB・RZ縮小・CGT厳密求解**など「何が証明できるか」を変える手法の標的である(§9)。

## 7. `USE_POTENTIAL_RZONE` の決定的segfaultと修正

文書化オプション `USE_POTENTIAL_RZONE=true` が、RZS-TT/PTいずれでも探索序盤で**決定的にsegfault**する。gdbで追うと、`WeichiQuickWinHandler` の `hasPotentialRZone`/`hasBensonSequence` にある**4つのコネクタ着手ループ**が、着手前の空点チェックなしに `m_board.play()` を呼び、占有点で null block を生成→`WeichiBoard::updateSiblings`(WeichiBoard.cpp:351)で参照して落ちる。**同ファイル138行に作者自身の同じガード**(`if (grid.getColor() != COLOR_NONE) { continue; }`)があるのに、この4ループだけ欠落していた。

修正は各 `play` 直前に同ガードを移植(4箇所)。**健全性検証**: 既に健全に証明済みの9問を patched potential-RZ で再解 → **9/9 判定一致(全UCT_WIN)・実探索3.7k–34k sims・偽陽性0**。クラッシュを除去し結果を変えない、正当性修正である(求解数は増やさない)。詳細と patch は upstream の [issue/PR](https://github.com/rlglab/study-LD-RZ/issues) 参照。

## 8. 知識フラグの負の結果(soundnessの罠)

フロンティア攻略に `USE_EARLY_LIFE=true` + `USE_PATTERN_EYE=true` を試したところ、28問中26問が0.01秒で"UCT_WIN"となった。しかし中身は **sims=0 / best=PASS / 木2.4 KB**——探索ゼロで「もう活き」と即断した**偽陽性**である。同一問題をTT/PTは300s・60万simsを尽くしてUCT_UNKNOWN(未証明)としている。cfgコメントが明示するとおり、これらのフラグは**健全なBenson活き判定をヒューリスティックに置換**する(`False: use Benson`)。証明ソルバでは「落ちない」≠「正しい」であり、これらは proof frontier の拡張には使えない。教訓: フラグを足す前にsoundnessを確認すべし。

## 9. Threats to Validity / 今後

- **母数差**: 本117問 vs 論文106問。率で比較。
- **CPU交絡**: §5のとおりL2は仮説。PMU測定不可。「GPU世代比」ではなく「リグ世代比」。
- **単一走行/単一ハード**: 走行間分散は小(§3)だが、他世代CPUでの制御実験は未実施。
- **RZone TTの解順依存**: PTは問題間でRZを永続再利用するため、単一セッション内の解順に依存しうる(本走行は全117問を1プロセスで一括処理)。
- **今後**: 真フロンティア28問へ **セキDB(arXiv:2411.05565系)/ RZ縮小(arXiv:2510.00689)/ CGT厳密求解** を投入し、手法律速の問題を崩す。NN難判定部分木→CGT厳密求解のハイブリッドは未開拓。

## 引用

- C.-C. Shih, T.-R. Wu, T. H. Wei, Y.-S. Hsu, H. Guei, I-C. Wu. *A Study of Solving Life-and-Death Problems in Go Using Relevance-Zone Based Solvers*. IEEE Transactions on Games, 2025. コードおよび参照値の出典: [rlglab/study-LD-RZ](https://github.com/rlglab/study-LD-RZ)。
