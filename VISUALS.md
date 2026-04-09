# How to Use This Tool

This file is the hands-on guide; **FEATURES.md** lists capabilities, offline vs. AI behavior, dataset dropdown semantics, and AI setup steps. **PIPELINE.md** describes data flow end-to-end.

## Prerequisites

- LLVM built with `llvm-config` on `PATH` (or set `LLVM_CONFIG`). The pipeline auto-detects tools from a sibling `llvm-project/build/` directory.
- Python 3 (for local HTTP server).
- A web browser.
- Linux `perf` (optional, CPU profiling) or ROCm `rocprof` (optional, GPU profiling).

## Quick Start — From C Source (recommended)

```bash
./run_pipeline.sh testcases/jacobi_stencil.c licm
```

This single command compiles the C source, applies the LLVM `licm` pass, runs `ll-dump` + profiler + remarks, and opens the visualization at `http://localhost:8765/`. LLVM tools are auto-detected. Use `--no-serve` to skip the HTTP server, `--port N` to change the port.

More examples:

```bash
./run_pipeline.sh testcases/gpu_reduction.c loop-unroll              # GPU kernel
./run_pipeline.sh myfile.c "loop-unroll,licm" --port 9000            # chained passes
PROFILER=rocprof ./run_pipeline.sh kernel.c loop-unroll              # force GPU profiling
```

## Quick Start — Pre-built datasets (no LLVM needed)

```bash
cd web
python3 -m http.server 8765
```

Open **http://localhost:8765/**. Use the **transformation dropdown** (top-left) to switch between curated examples (Loop Tiling, Unrolling, Interchange, Fusion, LICM, GPU demos, etc.). Those entries load **static JSON** under `web/datasets/` — useful for demos and teaching without building LLVM IR.

## Full pipeline from pre-existing IR

If you already have `.ll` files:

```bash
./scripts/analyze.sh path/to/before.ll path/to/after.ll
```

This builds `ll-dump` if missing, writes `web/before.json` and `web/after.json` (CFG, loops, instruction mix, dependencies, memory patterns, cost/impact, critical path), then runs **`perf stat`** (CPU) or **`rocprof`** (GPU IR / `GPU_ARCH` / `PROFILER=rocprof`) when the tool is installed, producing `web/perf_compare.json`. Optional **`OPT_PASS=licm`** (for example) can emit `remarks.json`. Then it starts the HTTP server. **No AI is required** — every visualization works offline.

## Manual steps (advanced)

### 1. Build the JSON extractor

```bash
make LLVM_CONFIG=/path/to/llvm-config
```

### 2. Generate JSON from IR

**Before/after comparison:**

```bash
./ll-dump before.ll -o web/before.json
./ll-dump after.ll  -o web/after.json
```

### 3. Add performance data (optional)

**CPU (automated):**

```bash
./scripts/run-perf.sh before.ll after.ll web/
```

This runs each binary 5 times (configurable: `PERF_RUNS=10 ./scripts/run-perf.sh ...`) and writes averaged counters.

**GPU (automated):**

```bash
GPU_ARCH=gfx90a ./scripts/run-rocprof.sh before.ll after.ll web/
```

### 4. Serve and open

```bash
cd web && python3 -m http.server 8765
```

Open **http://localhost:8765/** in your browser.

### 5. Interact

| Action | How |
|--------|-----|
| Switch transformation / dataset | Top-left dropdown (curated library or your saved `web/datasets/` folders) |
| Compare before/after CFGs | Click **Show diff** |
| Animate morph transition | Click **Morph** |
| Inspect a basic block | Click any CFG node |
| Zoom / pan | Scroll wheel / drag background |
| Rearrange nodes | Drag them |
| Animate loop execution | Press **Play** (single-view mode) |
| Toggle dark mode | Click the moon icon |
| Hierarchical layout | Click **Hierarchical layout** at bottom |
| Reset CFG positions | Click **Reset layout** |
| Rule-based insights (offline) | **✨ Insights** → **Generate** (no API configured) |
| AI insights & chat (optional) | **⚙ AI** — set **OpenAI**, **Anthropic**, **Ollama**, or **custom**. Then **✨ Insights** / **💬 Chat** — see **FEATURES.md** |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Blank page / "No JSON found" | Ensure JSON files exist in `web/` (or under the dataset path selected in the dropdown) and the server was started from `web/`. |
| Show diff grayed out | Both `before.json` and `after.json` must exist and share at least one function name. |
| Port in use | Use `--port N` with `run_pipeline.sh`, or `PORT=8766 ./scripts/analyze.sh ...`, or `python3 -m http.server 8766`. |
| `ll-dump` link failure | Verify `LLVM_CONFIG` points to the correct LLVM build. |
| No perf bar chart | `perf` or `rocprof` missing — charts need `perf_compare.json`; CFG still loads. |
| AI chat / insights errors | Check API key and endpoint in **⚙ AI**; the app falls back to rule-based text if the call fails. |
| Pass had no effect | The pipeline warns you if `diff` is zero. Try a different pass or a source with more complex loops. |
