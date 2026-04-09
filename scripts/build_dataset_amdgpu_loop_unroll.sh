#!/usr/bin/env bash
# Regenerate web/datasets/amdgpu-loop-unroll using repo tooling:
#   OpenMP offload IR (emit-llvm) with -fno-unroll-loops vs -funroll-loops
#   ll-dump → before.json / after.json
#   Link two host+device executables → scripts/rocprof-compare-bins.sh → perf_compare.json
#
# If rocprof / GPU runtime is unavailable, JSON is still refreshed; perf is skipped.
#
# Usage:
#   ./scripts/build_dataset_amdgpu_loop_unroll.sh
# Environment:
#   CLANG    — default clang (need OpenMP offload to amdgcn, e.g. AOMP or LLVM build)
#   GPU_ARCH — default gfx90a or from rocminfo
#   PERF_RUNS, ROCPROF — same as rocprof-compare-bins.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TC="$ROOT_DIR/testcases/amdgpu-loop-unroll"
DS="$ROOT_DIR/web/datasets/amdgpu-loop-unroll"
CLANG="${CLANG:-clang}"

GPU_ARCH="${GPU_ARCH:-gfx90a}"
if command -v rocminfo &>/dev/null; then
  G=$(rocminfo 2>/dev/null | grep -oP 'gfx\w+' | head -1)
  [ -n "$G" ] && GPU_ARCH="$G"
fi

OFFLOAD_FLAGS=(
  -fopenmp
  -fopenmp-targets=amdgcn-amd-amdhsa
  -Xopenmp-target=amdgcn-amd-amdhsa
  -march="$GPU_ARCH"
  -O2
)

mkdir -p "$DS"

if [ ! -f "$ROOT_DIR/ll-dump" ]; then
  echo "==> Building ll-dump..."
  make -C "$ROOT_DIR" -j"$(nproc)" LLVM_CONFIG="${LLVM_CONFIG:-llvm-config}" 2>/dev/null || \
    make -C "$ROOT_DIR" LLVM_CONFIG="${LLVM_CONFIG:-llvm-config}"
fi

echo "==> Emitting host+device LLVM IR (unroll off vs on), GPU_ARCH=$GPU_ARCH..."
"$CLANG" "${OFFLOAD_FLAGS[@]}" -fno-unroll-loops -emit-llvm -S \
  "$TC/bench_offload.c" -o "$TC/offload_before.ll"
"$CLANG" "${OFFLOAD_FLAGS[@]}" -funroll-loops -emit-llvm -S \
  "$TC/bench_offload.c" -o "$TC/offload_after.ll"

echo "==> ll-dump → JSON (fat modules: host + embedded device; pick kernel in UI)..."
"$ROOT_DIR/ll-dump" "$TC/offload_before.ll" -o "$DS/before.json"
"$ROOT_DIR/ll-dump" "$TC/offload_after.ll" -o "$DS/after.json"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "==> Linking offload benchmarks for rocprof..."
if "$CLANG" "${OFFLOAD_FLAGS[@]}" -fno-unroll-loops "$TC/bench_offload.c" -o "$TMPDIR/before_bin" 2>/dev/null; then
  if "$CLANG" "${OFFLOAD_FLAGS[@]}" -funroll-loops "$TC/bench_offload.c" -o "$TMPDIR/after_bin" 2>/dev/null; then
    if command -v rocprof &>/dev/null; then
      echo "==> rocprof → perf_compare.json..."
      GPU_ARCH="$GPU_ARCH" "$ROOT_DIR/scripts/rocprof-compare-bins.sh" \
        "$TMPDIR/before_bin" "$TMPDIR/after_bin" "$DS"
    else
      echo "==> Skipping perf_compare.json: rocprof not on PATH."
    fi
  else
    echo "==> Skipping perf: failed to link after_bin (check OpenMP offload toolchain)."
  fi
else
  echo "==> Skipping perf: failed to link before_bin (check OpenMP offload toolchain)."
fi

echo "==> Dataset amdgpu-loop-unroll updated under $DS"
