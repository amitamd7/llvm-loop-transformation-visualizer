#!/usr/bin/env bash
# Regenerate web/datasets/loop-split-openmp from sources using ONLY repo tooling:
#   clang (emit-llvm) → ll-dump → before.json / after.json
#   scripts/run-perf.sh → perf_compare.json (perf stat, PERF_RUNS runs averaged)
#
# Usage:
#   ./scripts/build_dataset_loop_split_openmp.sh
# Environment:
#   CLANG       — default: clang (use your tiwari_loop_splitting build, e.g.
#               CLANG=$LLVM_BUILD/bin/clang)
#   LLVM_CONFIG — for make ll-dump (default: llvm-config)
#   PERF_RUNS   — passed through to run-perf.sh (default 5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TC="$ROOT_DIR/testcases/loop-split-openmp"
DS="$ROOT_DIR/web/datasets/loop-split-openmp"
CLANG="${CLANG:-clang}"

mkdir -p "$DS"

if [ ! -f "$ROOT_DIR/ll-dump" ]; then
  echo "==> Building ll-dump..."
  make -C "$ROOT_DIR" -j"$(nproc)" LLVM_CONFIG="${LLVM_CONFIG:-llvm-config}" 2>/dev/null || \
    make -C "$ROOT_DIR" LLVM_CONFIG="${LLVM_CONFIG:-llvm-config}"
fi

echo "==> Emitting LLVM IR (before = no split, after = OpenMP split)..."
"$CLANG" -O1 -emit-llvm -S "$TC/bench_before.c" -o "$TC/before.ll"
"$CLANG" -O1 -fopenmp -fopenmp-version=60 -emit-llvm -S "$TC/bench_after.c" -o "$TC/after.ll"

echo "==> ll-dump → JSON..."
"$ROOT_DIR/ll-dump" "$TC/before.ll" -o "$DS/before.json"
"$ROOT_DIR/ll-dump" "$TC/after.ll" -o "$DS/after.json"

if command -v perf &>/dev/null; then
  echo "==> perf stat → perf_compare.json (run-perf.sh)..."
  CLANG="$CLANG" "$ROOT_DIR/scripts/run-perf.sh" "$TC/before.ll" "$TC/after.ll" "$DS"
else
  echo "==> Skipping perf_compare.json: 'perf' not installed (install linux-tools-\$(uname -r))."
fi

echo "==> Dataset loop-split-openmp updated under $DS"
