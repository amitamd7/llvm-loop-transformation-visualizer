#!/usr/bin/env bash
# run-transform.sh — C source + opt pass → before/after IR → analyze.sh
#
# Usage:
#   ./scripts/run-transform.sh testcases/matrix_traversal.c loop-unroll
#   ./scripts/run-transform.sh source.c "loop-unroll,licm"
#   OPT=/path/to/opt CLANG=/path/to/clang ./scripts/run-transform.sh source.c loop-interchange
#
# Prefer using the root-level run_pipeline.sh which wraps this with
# auto-detection and a cleaner interface.

set -euo pipefail

SOURCE="${1:?Usage: $0 source.c pass-name}"
PASS="${2:?Usage: $0 source.c pass-name}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CLANG="${CLANG:-clang}"
OPT="${OPT:-opt}"
PREP_PASSES="${PREP_PASSES:-mem2reg,lcssa,loop-simplify}"

TMPDIR_RT=$(mktemp -d)
trap "rm -rf $TMPDIR_RT" EXIT

BEFORE_LL="$TMPDIR_RT/before.ll"
AFTER_LL="$TMPDIR_RT/after.ll"
RAW_LL="$TMPDIR_RT/raw.ll"

echo "============================================"
echo "  Loop-Transform Visualiser — run-transform"
echo "============================================"
echo "  Source : $SOURCE"
echo "  Pass   : $PASS"
echo "  Clang  : $($CLANG --version 2>&1 | head -1)"
echo "  Opt    : $($OPT --version 2>&1 | head -1)"
echo "============================================"
echo ""

echo "==> [1/4] Compiling $SOURCE → raw IR (no optnone)..."
$CLANG -O0 -Xclang -disable-O0-optnone -emit-llvm -S "$SOURCE" -o "$RAW_LL"

echo "==> [2/4] Applying prep passes ($PREP_PASSES) → before.ll..."
$OPT -passes="$PREP_PASSES" "$RAW_LL" -S -o "$BEFORE_LL"

BEFORE_LINES=$(wc -l < "$BEFORE_LL")
echo "    before.ll: $BEFORE_LINES lines"

echo "==> [3/4] Applying opt -passes=$PASS → after.ll..."
$OPT -passes="$PASS" "$BEFORE_LL" -S -o "$AFTER_LL" 2>&1 || {
  echo "ERROR: opt -passes=$PASS failed. Check that the pass name is valid."
  exit 1
}

AFTER_LINES=$(wc -l < "$AFTER_LL")
echo "    after.ll:  $AFTER_LINES lines"

echo ""
if diff -q "$BEFORE_LL" "$AFTER_LL" >/dev/null 2>&1; then
  echo "WARNING: before.ll and after.ll are IDENTICAL."
  echo "         The pass '$PASS' had no effect on this input."
else
  DIFF_LINES=$( (diff "$BEFORE_LL" "$AFTER_LL" || true) | wc -l )
  echo "==> Transformation produced $DIFF_LINES lines of diff"
  echo "    (before: $BEFORE_LINES lines → after: $AFTER_LINES lines)"
fi

echo ""
echo "==> [4/4] Running analysis pipeline (ll-dump + perf stat + serve)..."
exec "$SCRIPT_DIR/analyze.sh" "$BEFORE_LL" "$AFTER_LL"
