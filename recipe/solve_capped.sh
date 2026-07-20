#!/usr/bin/env bash
# Solve study-LD-RZ tsumego problems at NUM_THREAD=20, ONE problem per process.
#
# Why one process per problem: a long batch in a single CGI accumulates the board
# transposition table across problems and eventually exhausts RAM. A fresh process
# per problem keeps peak memory bounded to one search tree.
#
# Why the cgroup cap: each solve runs inside `systemd-run --scope` with a hard
# MemoryMax (swap disabled), so a huge proof tree is OOM-killed cleanly by the
# kernel — only that one solver process dies, the host / WSL never does.
#
# Usage:
#   LDRZ_ROOT=/path/to/built/study-LD-RZ \
#   LIBTORCH_CUDART=/path/to/libcudart-XXXX.so.13 \
#   ./solve_capped.sh problems.list      # one "chao_volN_pNNN.json" per line
#
# Requires: cgroup v2 + memory controller + a systemd user manager
# (WSL2 with `systemd=true` in /etc/wsl.conf works). Place RZS-TT-20thread.cfg
# in $LDRZ_ROOT/cfg/ .  Build the solver per the study-LD-RZ build notes first.
set -u
ROOT="${LDRZ_ROOT:?set LDRZ_ROOT to your built study-LD-RZ checkout}"
PRELOAD="${LIBTORCH_CUDART:?set LIBTORCH_CUDART to the bundled cudart .so}"
CFG="${CFG:-cfg/RZS-TT-20thread.cfg}"
MEM_MAX="${MEM_MAX:-44G}"     # leave headroom for the OS; 44G on a 55G WSL budget
list="${1:?usage: solve_capped.sh <problem_list>}"

while read -r prob; do
  [ -z "$prob" ] && continue
  printf '%s\n' "$prob" > "$ROOT/candidate.list"
  systemd-run --user --scope -p MemoryMax="$MEM_MAX" -p MemorySwapMax=0 \
    bash -c "cd '$ROOT' && env -u LD_LIBRARY_PATH LD_PRELOAD='$PRELOAD' \
             ./Release/CGI -conf_file '$CFG' -mode tsumego_solver"
  st=$(python3 - "$ROOT/result/result_${prob%.json}.json" <<'PY'
import json, sys, os
f = sys.argv[1]
print(json.load(open(f))['RootStatus'] if os.path.exists(f) else 'no-result (OOM/timeout)')
PY
)
  printf '[%s] %-24s -> %s\n' "$(date +%H:%M:%S)" "${prob%.json}" "$st"
done < "$list"
