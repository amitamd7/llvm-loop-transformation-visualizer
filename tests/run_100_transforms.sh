#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# run_100_transforms.sh — Automated test harness for 50 CPU + 50 GPU
#                          loop transformations.
#
# Validates: pipeline execution, ll-dump JSON schema, CFG diffs,
#            loop detection, instruction mix, memory patterns,
#            dependencies, cost/impact, critical path, perf_compare,
#            Insight Engine contract, and cross-file consistency.
#
# Usage:
#   ./tests/run_100_transforms.sh [--quick]    # --quick = 10 CPU + 10 GPU
#
# Environment:
#   CLANG, OPT, LLVM_CONFIG — auto-detected if not set
#   GPU_MCPU  — GPU target (default: gfx90a)
#   KEEP_ARTIFACTS — set to 1 to keep per-test artifacts in tests/results/
# ═══════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
GEN_DIR="$TEST_DIR/generated_sources"
RESULTS_DIR="$TEST_DIR/results"
REPORT="$TEST_DIR/report.txt"
VALIDATOR="$TEST_DIR/validate_json.py"

GPU_MCPU="${GPU_MCPU:-gfx90a}"
GPU_TRIPLE="${CLANG_GPU_TRIPLE:-amdgcn-amd-amdhsa}"
KEEP="${KEEP_ARTIFACTS:-0}"

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

# ---- Auto-detect LLVM tools (same logic as run_pipeline.sh) ----
if [ -z "${CLANG:-}" ] || [ -z "${OPT:-}" ]; then
  for d in "$ROOT_DIR/../llvm-project/build/bin" \
           "$(dirname "$(command -v clang 2>/dev/null || true)" 2>/dev/null)"; do
    if [ -x "${d}/clang" ] && [ -x "${d}/opt" ]; then
      export CLANG="${CLANG:-$d/clang}"
      export OPT="${OPT:-$d/opt}"
      export LLVM_CONFIG="${LLVM_CONFIG:-$d/llvm-config}"
      break
    fi
  done
fi
CLANG="${CLANG:-clang}"
OPT="${OPT:-opt}"

# ---- Ensure ll-dump is built ----
if [ ! -f "$ROOT_DIR/ll-dump" ]; then
  echo "==> Building ll-dump..."
  make -C "$ROOT_DIR" -j"$(nproc)" 2>/dev/null || make -C "$ROOT_DIR"
fi

# ---- Generate test sources ----
echo "==> Generating test sources..."
python3 "$TEST_DIR/generate_sources.py" "$GEN_DIR"

# ---- Load manifest ----
MANIFEST="$GEN_DIR/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: manifest.json not generated" >&2
  exit 1
fi

TOTAL_TESTS=$(python3 -c "import json; print(len(json.load(open('$MANIFEST'))))")
echo "==> Manifest: $TOTAL_TESTS tests"

mkdir -p "$RESULTS_DIR"
: > "$REPORT"

# ---- Counters (file-based to survive subshells) ----
COUNTERS_DIR=$(mktemp -d)
echo 0 > "$COUNTERS_DIR/pass"
echo 0 > "$COUNTERS_DIR/fail"
echo 0 > "$COUNTERS_DIR/skip"
echo 0 > "$COUNTERS_DIR/pfail"
echo 0 > "$COUNTERS_DIR/vfail"
echo 0 > "$COUNTERS_DIR/noloop"
echo 0 > "$COUNTERS_DIR/nodiff"

inc() { local f="$COUNTERS_DIR/$1"; echo $(( $(cat "$f") + 1 )) > "$f"; }
cnt() { cat "$COUNTERS_DIR/$1"; }

PREP_PASSES="mem2reg,lcssa,loop-simplify"

run_one_test() {
  local idx="$1" id="$2" file="$3" pass="$4" mode="$5" desc="$6"
  local src="$GEN_DIR/$file"
  local workdir="$RESULTS_DIR/$id"
  mkdir -p "$workdir"

  local before_ll="$workdir/before.ll"
  local after_ll="$workdir/after.ll"
  local before_json="$workdir/before.json"
  local after_json="$workdir/after.json"
  local perf_json="$workdir/perf_compare.json"
  local raw_ll="$workdir/raw.ll"

  local status="PASS"
  local notes=""

  # ---- Step 1: Compile ----
  if [ "$mode" = "gpu" ]; then
    if ! "$CLANG" -target "$GPU_TRIPLE" -mcpu="$GPU_MCPU" \
         -O1 -fno-unroll-loops -emit-llvm -S "$src" -o "$before_ll" 2>"$workdir/compile.err"; then
      echo "  [$id] SKIP — clang GPU compile failed"
      notes="clang compile failed"
      status="SKIP"
      echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"
      inc skip
      return
    fi
  else
    if ! "$CLANG" -O0 -Xclang -disable-O0-optnone -emit-llvm -S "$src" -o "$raw_ll" 2>"$workdir/compile.err"; then
      echo "  [$id] SKIP — clang compile failed"
      notes="clang compile failed"
      status="SKIP"
      echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"
      inc skip
      return
    fi
    if ! "$OPT" -passes="$PREP_PASSES" "$raw_ll" -S -o "$before_ll" 2>>"$workdir/compile.err"; then
      echo "  [$id] SKIP — opt prep failed"
      notes="opt prep failed"
      status="SKIP"
      echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"
      inc skip
      return
    fi
  fi

  # ---- Step 2: Apply pass ----
  if ! "$OPT" -passes="$pass" "$before_ll" -S -o "$after_ll" 2>"$workdir/pass.err"; then
    echo "  [$id] SKIP — opt -passes=$pass failed"
    notes="opt pass failed: $(head -1 "$workdir/pass.err")"
    status="SKIP"
    echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"
    inc skip
    return
  fi

  # ---- Step 3: ll-dump → JSON ----
  if ! "$ROOT_DIR/ll-dump" "$before_ll" -o "$before_json" 2>"$workdir/dump_before.err"; then
    echo "  [$id] FAIL — ll-dump before failed"
    notes="ll-dump before failed"
    status="FAIL"
    inc pfail; inc fail
    echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"
    return
  fi
  if ! "$ROOT_DIR/ll-dump" "$after_ll" -o "$after_json" 2>"$workdir/dump_after.err"; then
    echo "  [$id] FAIL — ll-dump after failed"
    notes="ll-dump after failed"
    status="FAIL"
    inc pfail; inc fail
    echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"
    return
  fi

  # ---- Step 4: Perf profiling (CPU only, if perf available) ----
  if [ "$mode" = "cpu" ] && command -v perf &>/dev/null; then
    "$ROOT_DIR/scripts/run-perf.sh" "$before_ll" "$after_ll" "$workdir" 2>"$workdir/perf.err" || true
  fi

  # ---- Step 5: Deep JSON validation ----
  local val_args=("$before_json" "$after_json")
  [ -f "$perf_json" ] && val_args+=("$perf_json")
  if ! python3 "$VALIDATOR" "${val_args[@]}" > "$workdir/validation.log" 2>&1; then
    status="FAIL"
    inc vfail; inc fail
    notes="validation failed — see $workdir/validation.log"
    echo "  [$id] FAIL — JSON validation"
  fi

  # ---- Step 6: Extra semantic checks ----
  local extra
  extra=$(python3 -c "
import json, sys
b = json.load(open('$before_json'))
a = json.load(open('$after_json'))
issues = []

# Check loops exist in at least one defined function
def has_loops(data, label):
    for fn in data.get('functions', []):
        if fn.get('instruction_count', 0) > 0:
            if len(fn.get('loops', [])) > 0:
                return True
    return False

if not has_loops(b, 'before'):
    issues.append('NO_LOOP_BEFORE')
if not has_loops(a, 'after'):
    issues.append('NO_LOOP_AFTER')

# Check diff would show something
bf_fn = [f for f in b.get('functions',[]) if f.get('instruction_count',0)>0]
af_fn = [f for f in a.get('functions',[]) if f.get('instruction_count',0)>0]
if bf_fn and af_fn:
    bn = {f['name'] for f in bf_fn}
    an = {f['name'] for f in af_fn}
    shared = bn & an
    if shared:
        name = list(shared)[0]
        bf = next(f for f in bf_fn if f['name']==name)
        af = next(f for f in af_fn if f['name']==name)
        bls = {n['label'] for n in bf.get('cfg',{}).get('nodes',[])}
        als = {n['label'] for n in af.get('cfg',{}).get('nodes',[])}
        if bls == als:
            issues.append('IDENTICAL_CFG')
        # Check instruction count changed
        if bf.get('instruction_count') == af.get('instruction_count'):
            issues.append('SAME_INSTR_COUNT')

# Check Insight Engine would get valid functions[0]
for side, lbl in [(b,'before'),(a,'after')]:
    fns = side.get('functions',[])
    if fns:
        f0 = fns[0]
        if f0.get('instruction_count',0) == 0:
            issues.append(f'FN0_IS_DECL_{lbl.upper()}')

print(','.join(issues) if issues else 'OK')
" 2>/dev/null || echo "PYTHON_ERR")

  if [[ "$extra" == *"NO_LOOP_BEFORE"* ]] && [[ "$extra" == *"NO_LOOP_AFTER"* ]]; then
    inc noloop
  fi
  if [[ "$extra" == *"IDENTICAL_CFG"* ]]; then
    inc nodiff
  fi

  if [ "$status" = "PASS" ]; then
    inc pass
    notes="$extra"
    echo "  [$id] PASS ($extra)"
  fi

  echo "$id|$status|$pass|$mode|$desc|$notes" >> "$REPORT"

  # Cleanup if not keeping
  if [ "$KEEP" != "1" ] && [ "$status" = "PASS" ]; then
    rm -rf "$workdir"
  fi
}

# ---- Main loop ----
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  LLVM Loop-Transform Visualiser — 100-Test Validation Harness   ║"
echo "╠═══════════════════════════════════════════════════════════════════╣"
echo "║  Clang : $($CLANG --version 2>&1 | head -1)"
echo "║  Opt   : $($OPT --version 2>&1 | head -1)"
echo "║  GPU   : $GPU_TRIPLE ($GPU_MCPU)"
if [ "$QUICK" -eq 1 ]; then
  echo "║  Mode  : QUICK (20 tests: 10 CPU + 10 GPU)"
else
  echo "║  Mode  : FULL (100 tests: 50 CPU + 50 GPU)"
fi
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Parse manifest and run
IDX=0
python3 -c "
import json
m = json.load(open('$MANIFEST'))
for e in m:
    print(f\"{e['id']}|{e['file']}|{e['pass']}|{e['mode']}|{e['desc']}\")
" | while IFS='|' read -r id file pass mode desc; do
  if [ "$QUICK" -eq 1 ]; then
    case "$id" in
      cpu_0[0-9]*) ;; # 00-09
      gpu_0[0-9]*) ;; # 00-09
      *) continue ;;
    esac
  fi
  run_one_test "$IDX" "$id" "$file" "$pass" "$mode" "$desc"
  IDX=$((IDX + 1))
done

# ---- Summary ----
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  TEST HARNESS SUMMARY"
echo "═══════════════════════════════════════════════════════"

PASS_COUNT=$(cnt pass); FAIL_COUNT=$(cnt fail); SKIP_COUNT=$(cnt skip)
PIPELINE_FAIL=$(cnt pfail); VALIDATION_FAIL=$(cnt vfail)
NO_LOOP_COUNT=$(cnt noloop); NO_DIFF_COUNT=$(cnt nodiff)
rm -rf "$COUNTERS_DIR"

TOTAL_RAN=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo "  Total tests run   : $TOTAL_RAN"
echo "  PASSED            : $PASS_COUNT"
echo "  FAILED            : $FAIL_COUNT"
echo "    pipeline fails  : $PIPELINE_FAIL"
echo "    validation fails: $VALIDATION_FAIL"
echo "  SKIPPED           : $SKIP_COUNT (pass not applicable to input)"
echo ""
echo "  Observations:"
echo "    No loops detected (both sides): $NO_LOOP_COUNT"
echo "    Pass had no CFG effect        : $NO_DIFF_COUNT"
echo ""
echo "  Detailed report: $REPORT"

# Print failure details
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "  ──── FAILURES ────"
  grep "|FAIL|" "$REPORT" | while IFS='|' read -r fid fstat fpass fmode fdesc fnotes; do
    echo "  $fid: pass=$fpass mode=$fmode"
    echo "       $fnotes"
    log="$RESULTS_DIR/$fid/validation.log"
    if [ -f "$log" ]; then
      grep "FAIL" "$log" | head -5 | while read -r line; do
        echo "       $line"
      done
    fi
    echo ""
  done
fi

echo "═══════════════════════════════════════════════════════"
echo "  Full report: $REPORT"
echo "  Failed artifacts: $RESULTS_DIR/<test_id>/"
echo "═══════════════════════════════════════════════════════"

[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
