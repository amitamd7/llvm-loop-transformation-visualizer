#!/usr/bin/env bash
# analyze.sh — Full pipeline: IR → JSON + perf/rocprof data → serve visualization
#
# Usage:
#   ./scripts/analyze.sh before.ll after.ll
#   GPU_ARCH=gfx90a ./scripts/analyze.sh before.ll after.ll   # force GPU profiling
#
# Auto-detects GPU target triples in the IR files and chooses rocprof (GPU) or
# perf stat (CPU) accordingly. Override with PROFILER=perf or PROFILER=rocprof.

set -euo pipefail

BEFORE_LL="${1:?Usage: $0 before.ll after.ll}"
AFTER_LL="${2:?Usage: $0 before.ll after.ll}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WEBDIR="$ROOT_DIR/web"
PORT="${PORT:-8765}"

if [ ! -f "$ROOT_DIR/ll-dump" ]; then
  echo "==> Building ll-dump..."
  make -C "$ROOT_DIR" -j$(nproc) 2>/dev/null || make -C "$ROOT_DIR"
fi

echo "==> Extracting CFG from before IR..."
"$ROOT_DIR/ll-dump" "$BEFORE_LL" -o "$WEBDIR/before.json"

echo "==> Extracting CFG from after IR..."
"$ROOT_DIR/ll-dump" "$AFTER_LL" -o "$WEBDIR/after.json"

# --- Profiler selection ---
is_gpu_ir() {
  grep -qE 'triple\s*=\s*"(amdgcn|nvptx|spir)' "$1" 2>/dev/null
}

choose_profiler() {
  if [ -n "${PROFILER:-}" ]; then
    echo "$PROFILER"
    return
  fi
  if [ -n "${GPU_ARCH:-}" ]; then
    echo "rocprof"
    return
  fi
  if is_gpu_ir "$BEFORE_LL" || is_gpu_ir "$AFTER_LL"; then
    echo "rocprof"
    return
  fi
  echo "perf"
}

PROF=$(choose_profiler)

if [ "$PROF" = "rocprof" ]; then
  if command -v rocprof &>/dev/null; then
    echo "==> GPU target detected — running rocprof profiling..."
    "$SCRIPT_DIR/run-rocprof.sh" "$BEFORE_LL" "$AFTER_LL" "$WEBDIR"
  else
    echo "==> GPU target detected but rocprof not found, skipping GPU profiling."
    echo "    Install ROCm and ensure rocprof is on PATH."
  fi
else
  if command -v perf &>/dev/null; then
    echo "==> Running CPU performance profiling (perf stat)..."
    "$SCRIPT_DIR/run-perf.sh" "$BEFORE_LL" "$AFTER_LL" "$WEBDIR"
  else
    echo "==> perf not available, skipping CPU performance profiling."
    echo "    Install linux-tools-$(uname -r) for hardware counter data."
  fi
fi

# --- Optimization remarks (if opt is available) ---
if command -v opt &>/dev/null && [ -n "${OPT_PASS:-}" ]; then
  echo "==> Extracting optimization remarks for pass '$OPT_PASS'..."
  opt -passes="$OPT_PASS" \
    -pass-remarks="$OPT_PASS" \
    -pass-remarks-missed="$OPT_PASS" \
    -pass-remarks-analysis="$OPT_PASS" \
    -pass-remarks-output="$WEBDIR/remarks.yaml" \
    "$BEFORE_LL" -S -o /dev/null 2>/dev/null || true
  if [ -f "$WEBDIR/remarks.yaml" ]; then
    python3 "$SCRIPT_DIR/parse-remarks.py" "$WEBDIR/remarks.yaml" "$WEBDIR/remarks.json" 2>/dev/null && \
      echo "    Wrote remarks.json" || \
      echo "    Remarks YAML found but parsing failed (parse-remarks.py missing?)"
  fi
fi

# --- Find a free port (portable, uses python3) ---
find_free_port() {
  local p="$1" max=$(( $1 + 20 ))
  while [ "$p" -le "$max" ]; do
    if ! python3 -c "import socket; s=socket.socket(); s.settimeout(0.1); s.connect(('127.0.0.1',$p))" 2>/dev/null; then
      echo "$p"; return
    fi
    p=$(( p + 1 ))
  done
  echo "$1"
}

PORT=$(find_free_port "$PORT")

echo ""
echo "======================================"
echo "  Visualization ready!"
echo "  Open: http://localhost:$PORT/"
echo "  Dataset: 'Latest analysis' (first dropdown entry)"
echo "======================================"
echo ""

cd "$WEBDIR" && python3 -m http.server "$PORT"
