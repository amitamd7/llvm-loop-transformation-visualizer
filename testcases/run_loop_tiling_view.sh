#!/usr/bin/env bash
# Emit before/after JSON for the loop-tiling demo into web/. Run from repo root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ ! -x ./ll-dump ]]; then
  echo "Build first: make LLVM_CONFIG=/path/to/llvm-config" >&2
  exit 1
fi
./ll-dump testcases/loop_tiling_before.ll -o web/before.json
./ll-dump testcases/loop_tiling_after.ll -o web/after.json
echo "Wrote web/before.json and web/after.json"
echo "Serve:  cd web && python3 -m http.server 8765"
echo "Then:   open http://127.0.0.1:8765/  → Show diff → function tile_demo"
