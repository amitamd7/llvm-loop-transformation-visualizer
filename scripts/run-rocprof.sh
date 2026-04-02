#!/usr/bin/env bash
# run-rocprof.sh — Compile two LLVM IR files for GPU, run rocprof on each, produce perf_compare.json
#
# Usage:
#   ./scripts/run-rocprof.sh before.ll after.ll [output_dir]
#
# Requirements: clang (with offload support), rocprof, python3
# Output: perf_compare.json in output_dir (default: web/)
#
# Environment variables:
#   GPU_ARCH    — target GPU architecture (default: auto-detect via rocminfo)
#   PERF_RUNS   — number of profiling iterations (default: 5)
#   CLANG       — clang binary (default: clang)
#   ROCPROF     — rocprof binary (default: rocprof)

set -euo pipefail

BEFORE_LL="${1:?Usage: $0 before.ll after.ll [output_dir]}"
AFTER_LL="${2:?Usage: $0 before.ll after.ll [output_dir]}"
OUTDIR="${3:-web}"

CLANG="${CLANG:-clang}"
ROCPROF="${ROCPROF:-rocprof}"
RUNS="${PERF_RUNS:-5}"

detect_gpu_arch() {
  if [ -n "${GPU_ARCH:-}" ]; then
    echo "$GPU_ARCH"
    return
  fi
  if command -v rocminfo &>/dev/null; then
    local arch
    arch=$(rocminfo 2>/dev/null | grep -oP 'gfx\w+' | head -1)
    if [ -n "$arch" ]; then
      echo "$arch"
      return
    fi
  fi
  echo "gfx90a"
}

ARCH=$(detect_gpu_arch)
echo "==> GPU target: $ARCH"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

is_offload_ir() {
  grep -qE 'triple\s*=\s*"amdgcn|nvptx|spir' "$1" 2>/dev/null
}

if is_offload_ir "$BEFORE_LL"; then
  echo "==> Compiling before IR (device IR, linking for $ARCH)..."
  $CLANG --offload-arch="$ARCH" -O0 -lm "$BEFORE_LL" -o "$TMPDIR/before_bin" 2>/dev/null || \
    $CLANG --offload-arch="$ARCH" -O0 "$BEFORE_LL" -o "$TMPDIR/before_bin"
else
  echo "==> Compiling before IR (host IR with -fopenmp --offload-arch=$ARCH)..."
  $CLANG -fopenmp --offload-arch="$ARCH" -O0 -lm "$BEFORE_LL" -o "$TMPDIR/before_bin" 2>/dev/null || \
    $CLANG -fopenmp --offload-arch="$ARCH" -O0 "$BEFORE_LL" -o "$TMPDIR/before_bin" 2>/dev/null || \
    $CLANG -O0 -lm "$BEFORE_LL" -o "$TMPDIR/before_bin" 2>/dev/null || \
    $CLANG -O0 "$BEFORE_LL" -o "$TMPDIR/before_bin"
fi

if is_offload_ir "$AFTER_LL"; then
  echo "==> Compiling after IR (device IR, linking for $ARCH)..."
  $CLANG --offload-arch="$ARCH" -O0 -lm "$AFTER_LL" -o "$TMPDIR/after_bin" 2>/dev/null || \
    $CLANG --offload-arch="$ARCH" -O0 "$AFTER_LL" -o "$TMPDIR/after_bin"
else
  echo "==> Compiling after IR (host IR with -fopenmp --offload-arch=$ARCH)..."
  $CLANG -fopenmp --offload-arch="$ARCH" -O0 -lm "$AFTER_LL" -o "$TMPDIR/after_bin" 2>/dev/null || \
    $CLANG -fopenmp --offload-arch="$ARCH" -O0 "$AFTER_LL" -o "$TMPDIR/after_bin" 2>/dev/null || \
    $CLANG -O0 -lm "$AFTER_LL" -o "$TMPDIR/after_bin" 2>/dev/null || \
    $CLANG -O0 "$AFTER_LL" -o "$TMPDIR/after_bin"
fi

cat > "$TMPDIR/metrics.txt" << 'METRICS'
pmc: SQ_INSTS_VALU SQ_INSTS_SALU SQ_INSTS_SMEM SQ_INSTS_VMEM SQ_WAVES
pmc: TCC_HIT TCC_MISS TCP_TCC_READ_REQ_sum TCP_TCC_WRITE_REQ_sum
pmc: SQ_INSTS_BRANCH SQ_INSTS_LDS
METRICS

run_rocprof() {
  local bin="$1" label="$2" outdir="$3"
  echo "==> Running rocprof on $label ($RUNS iterations)..."

  mkdir -p "$outdir"
  local total_time=0
  for i in $(seq "$RUNS"); do
    local rundir="$outdir/run_$i"
    mkdir -p "$rundir"

    $ROCPROF --stats -o "$rundir/stats.csv" "$bin" >/dev/null 2>&1 || true

    $ROCPROF -i "$TMPDIR/metrics.txt" -o "$rundir/counters.csv" "$bin" >/dev/null 2>&1 || true

    if [ -f "$rundir/stats.csv" ]; then
      local dur
      dur=$(tail -n +2 "$rundir/stats.csv" 2>/dev/null | awk -F',' '{sum += $NF} END {print sum+0}')
      total_time=$(echo "$total_time + $dur" | bc)
    fi
  done

  cat "$outdir"/run_*/counters.csv 2>/dev/null | head -1 > "$outdir/all_counters.csv"
  tail -q -n +2 "$outdir"/run_*/counters.csv 2>/dev/null >> "$outdir/all_counters.csv" 2>/dev/null || true

  echo "$total_time" > "$outdir/total_time_ns.txt"
}

run_rocprof "$TMPDIR/before_bin" "before" "$TMPDIR/prof_before"
run_rocprof "$TMPDIR/after_bin" "after" "$TMPDIR/prof_after"

echo "==> Generating perf_compare.json..."
python3 - "$TMPDIR/prof_before" "$TMPDIR/prof_after" "$OUTDIR/perf_compare.json" "$RUNS" "$ARCH" << 'PYEOF'
import sys, json, csv, os

def read_total_time(prof_dir, runs):
    try:
        with open(os.path.join(prof_dir, 'total_time_ns.txt')) as f:
            total_ns = float(f.read().strip())
        return total_ns / runs if runs > 0 else total_ns
    except:
        return None

def read_counters(prof_dir):
    csv_path = os.path.join(prof_dir, 'all_counters.csv')
    if not os.path.exists(csv_path):
        return {}
    totals = {}
    count = 0
    try:
        with open(csv_path) as f:
            reader = csv.DictReader(f)
            for row in reader:
                count += 1
                for k, v in row.items():
                    k = k.strip()
                    try:
                        val = float(v)
                        totals[k] = totals.get(k, 0) + val
                    except (ValueError, TypeError):
                        pass
    except:
        return {}
    if count > 0:
        for k in totals:
            totals[k] /= count
    return totals

def build_result(prof_dir, runs):
    r = {}
    avg_time_ns = read_total_time(prof_dir, runs)
    if avg_time_ns is not None:
        r['kernel_time_ns'] = round(avg_time_ns, 2)
        r['execution_time'] = round(avg_time_ns / 1e6, 4)

    c = read_counters(prof_dir)

    valu = c.get('SQ_INSTS_VALU', 0)
    salu = c.get('SQ_INSTS_SALU', 0)
    smem = c.get('SQ_INSTS_SMEM', 0)
    vmem = c.get('SQ_INSTS_VMEM', 0)
    waves = c.get('SQ_WAVES', 0)
    branch = c.get('SQ_INSTS_BRANCH', 0)
    lds = c.get('SQ_INSTS_LDS', 0)

    if valu: r['valu_insts'] = round(valu)
    if salu: r['salu_insts'] = round(salu)
    if smem: r['smem_insts'] = round(smem)
    if vmem: r['vmem_insts'] = round(vmem)
    if waves: r['waves'] = round(waves)
    if branch: r['gpu_branch_insts'] = round(branch)
    if lds: r['lds_insts'] = round(lds)

    total_insts = valu + salu + smem + vmem + branch + lds
    if total_insts: r['instructions'] = round(total_insts)

    tcc_hit = c.get('TCC_HIT', 0)
    tcc_miss = c.get('TCC_MISS', 0)
    if tcc_hit + tcc_miss > 0:
        r['l2_hit_rate'] = round(tcc_hit / (tcc_hit + tcc_miss) * 100, 2)

    tcp_read = c.get('TCP_TCC_READ_REQ_sum', 0)
    tcp_write = c.get('TCP_TCC_WRITE_REQ_sum', 0)
    if tcp_read + tcp_write > 0:
        r['l1_to_l2_traffic'] = round(tcp_read + tcp_write)

    return r

runs = int(sys.argv[4]) if len(sys.argv) > 4 else 5
arch = sys.argv[5] if len(sys.argv) > 5 else 'unknown'

bm = build_result(sys.argv[1], runs)
am = build_result(sys.argv[2], runs)

out = {
    'runs': runs,
    'device': arch,
    'profiler': 'rocprof',
    'before': bm,
    'after': am
}

with open(sys.argv[3], 'w') as f:
    json.dump(out, f, indent=2)
    f.write('\n')
print(f"Wrote {sys.argv[3]} (GPU: {arch}, averaged over {runs} runs)")
PYEOF

echo "==> Done. GPU performance data written to $OUTDIR/perf_compare.json"
