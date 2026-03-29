#!/usr/bin/env bash
# analyze.sh — Full pipeline: IR → JSON + perf data → serve visualization
#
# Usage:
#   ./scripts/analyze.sh before.ll after.ll
#
# This is the single command a user runs. It:
#   1. Runs ll-dump to extract CFG JSON from both IR files
#   2. Runs perf stat to measure performance of both versions
#   3. Starts a local web server and opens the visualizer

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

if command -v perf &>/dev/null; then
  echo "==> Running performance profiling..."
  "$SCRIPT_DIR/run-perf.sh" "$BEFORE_LL" "$AFTER_LL" "$WEBDIR"
else
  echo "==> perf not available, skipping performance profiling."
  echo "    Install linux-tools-$(uname -r) for hardware counter data."
fi

echo ""
echo "======================================"
echo "  Visualization ready!"
echo "  Open: http://localhost:$PORT/"
echo "======================================"
echo ""

cd "$WEBDIR" && python3 -m http.server "$PORT"
