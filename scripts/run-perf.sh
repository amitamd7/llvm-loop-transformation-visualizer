#!/usr/bin/env bash
# run-perf.sh — Compile two LLVM IR files, run perf stat on each, produce perf_compare.json
#
# Usage:
#   ./scripts/run-perf.sh before.ll after.ll [output_dir]
#
# Requirements: clang, perf (linux), python3
# Output: perf_compare.json in output_dir (default: web/)

set -euo pipefail

BEFORE_LL="${1:?Usage: $0 before.ll after.ll [output_dir]}"
AFTER_LL="${2:?Usage: $0 before.ll after.ll [output_dir]}"
OUTDIR="${3:-web}"

CLANG="${CLANG:-clang}"
PERF="${PERF:-perf}"
RUNS="${PERF_RUNS:-5}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "==> Compiling before IR..."
$CLANG -O0 -lm "$BEFORE_LL" -o "$TMPDIR/before_bin" 2>/dev/null || \
  $CLANG -O0 "$BEFORE_LL" -o "$TMPDIR/before_bin"

echo "==> Compiling after IR..."
$CLANG -O0 -lm "$AFTER_LL" -o "$TMPDIR/after_bin" 2>/dev/null || \
  $CLANG -O0 "$AFTER_LL" -o "$TMPDIR/after_bin"

run_perf() {
  local bin="$1" label="$2" outfile="$3"
  echo "==> Running perf stat on $label ($RUNS iterations)..."
  $PERF stat -r "$RUNS" -e task-clock,cycles,instructions,cache-references,cache-misses,LLC-loads,LLC-load-misses,branches,branch-misses \
    -x ',' -o "$outfile" "$bin" 2>/dev/null || \
  $PERF stat -r "$RUNS" -e task-clock,cycles,instructions,branches,branch-misses \
    -x ',' -o "$outfile" "$bin"
}

run_perf "$TMPDIR/before_bin" "before" "$TMPDIR/perf_before.csv"
run_perf "$TMPDIR/after_bin" "after" "$TMPDIR/perf_after.csv"

echo "==> Generating perf_compare.json..."
python3 - "$TMPDIR/perf_before.csv" "$TMPDIR/perf_after.csv" "$OUTDIR/perf_compare.json" "$RUNS" << 'PYEOF'
import sys, json, re

def parse_perf_csv(path):
    metrics = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(',')
            if len(parts) < 3:
                continue
            try:
                val = float(parts[0].replace('<', '').replace('>', ''))
            except ValueError:
                continue
            name = parts[2].strip()
            metrics[name] = val
    return metrics

def build_result(m):
    r = {}
    if 'task-clock' in m:
        r['execution_time'] = round(m['task-clock'], 2)
    if 'cycles' in m:
        r['cycles'] = int(m['cycles'])
    if 'instructions' in m:
        r['instructions'] = int(m['instructions'])
    if r.get('cycles') and r.get('instructions'):
        r['ipc'] = round(r['instructions'] / r['cycles'], 2)
    if 'cache-references' in m and m['cache-references'] > 0 and 'cache-misses' in m:
        r['l1_miss_rate'] = round(m['cache-misses'] / m['cache-references'] * 100, 2)
    if 'LLC-loads' in m and m['LLC-loads'] > 0 and 'LLC-load-misses' in m:
        r['llc_miss_rate'] = round(m['LLC-load-misses'] / m['LLC-loads'] * 100, 2)
    if 'branches' in m and m['branches'] > 0 and 'branch-misses' in m:
        r['branch_miss_rate'] = round(m['branch-misses'] / m['branches'] * 100, 2)
    return r

bm = parse_perf_csv(sys.argv[1])
am = parse_perf_csv(sys.argv[2])
runs = int(sys.argv[4]) if len(sys.argv) > 4 else 5
out = {'runs': runs, 'before': build_result(bm), 'after': build_result(am)}

with open(sys.argv[3], 'w') as f:
    json.dump(out, f, indent=2)
print(f"Wrote {sys.argv[3]} (averaged over {runs} runs)")
PYEOF

echo "==> Done. Performance data written to $OUTDIR/perf_compare.json"
