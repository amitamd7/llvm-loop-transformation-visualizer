# How the Tool Works

## Pipeline Overview

```
C/C++ source (.c/.cpp)        (or pre-existing .ll files)
     │                                │
     ▼                                │
  run_pipeline.sh                     │
  ┌─────────────────────┐            │
  │ clang → raw.ll      │            │
  │ opt (prep) → before │            │
  │ opt (pass) → after  │            │
  └─────────┬───────────┘            │
            │                         │
            ▼                         ▼
  ll-dump                     analyze.sh (from .ll)
     │                              │
     ▼                              ▼
 before.json / after.json     perf stat / rocprof → perf_compare.json
 (CFG, loops, mix, deps,           │
  memory, cost, impact,            │
  critical_path)              opt + parse-remarks.py → remarks.json
     │                              │
     └──────────┬───────────────────┘
                ▼
     index.html (browser) — offline rendering from JSON
                │
                ├── Rule-based insights & keyword chat (always available)
                │
                └── Optional: ⚙ AI → OpenAI / Anthropic / Ollama / custom API
                            for ✨ Insights and 💬 Chat (falls back on failure)
```

**Primary entry point:** `./run_pipeline.sh input.c <pass>` auto-detects LLVM tools (`clang`, `opt`) from a sibling `llvm-project/build/` or `PATH`, compiles the source to clean-SSA IR, applies the specified LLVM pass, runs `ll-dump` on both IRs, profiles with `perf stat` or `rocprof` (auto-detected from IR triple), emits optimization remarks, and serves the visualization.

**From pre-existing IR:** `./scripts/analyze.sh before.ll after.ll` builds `ll-dump` if needed, runs `ll-dump` on both IRs into `web/before.json` and `web/after.json`, chooses **`run-perf.sh`** or **`run-rocprof.sh`** from the IR triple (or `PROFILER=` / `GPU_ARCH=`), then serves `web/` with Python's HTTP server.

## Step-by-Step

### 0. C/C++ source compilation (`run_pipeline.sh` only)

When using `run_pipeline.sh`, the script handles the full compilation chain:

1. `clang -O0 -Xclang -disable-O0-optnone -emit-llvm -S input.c -o raw.ll`
2. `opt -passes=mem2reg,lcssa,loop-simplify raw.ll -S -o before.ll` (clean SSA)
3. `opt -passes=<user-pass> before.ll -S -o after.ll` (transformed IR)

For GPU targets, compile with `-target amdgcn-amd-amdhsa -mcpu=gfx90a` or use OpenMP offload flags. The profiler is auto-selected based on the IR triple.

### 1. IR → JSON extraction (`ll-dump`)

The `ll-dump` tool (C++, linked against LLVM libraries) parses an `.ll` file and extracts:

- **Per-function CFG**: basic block nodes with IDs and labels, edges with source/target (including back-edges).
- **Loop analysis**: runs LLVM's `LoopInfoWrapperPass` to identify loop headers, depths, blocks, and trip counts via `ScalarEvolution`.
- **Instruction counts**: total and per-category (arithmetic, memory, branch, other) for each basic block.
- **Memory accesses**: array name, access pattern (stride-1 or strided), and type (load/store) for each loop.
- **Dependencies**: type (loop-carried, flow, anti, output), variable names, distance, and description.

Output: a single JSON file per IR file. The tool is fully generic and works on any valid LLVM IR regardless of the transformation applied.

### 2. Performance data (automated or manual)

`perf_compare.json` holds **before** / **after** hardware counter summaries:

- **`runs`** — how many executions were averaged (default 5); the UI shows **"Average of N runs"** once in the benchmark heading.
- **CPU** (from `run-perf.sh`): `execution_time`, `cycles`, `instructions`, `ipc`, cache/branch rates as available from `perf stat`.
- **GPU** (from `run-rocprof.sh`): `profiler: "rocprof"`, optional `device`, and GPU-oriented counters (VALU, VMEM, L2 hit rate, waves, etc.).

Some **curated** datasets ship hand-written or illustrative JSON (including optional `transform_insights` narratives). For a **fully data-driven** path, always regenerate this file with `run_pipeline.sh`, `run-perf.sh` / `run-rocprof.sh`, or `analyze.sh`. Override averaging with `PERF_RUNS=N`. Without `perf_compare.json`, charts are omitted; CFG and analysis panels still work.

### 3. Browser loads JSON

On page load, `index.html` fetches JSON relative to the page (or under a dataset prefix). Typical files:

1. `before.json` / `after.json` — comparison pair
2. `perf_compare.json` — before/after hardware counters for the bar chart (optional)
3. `remarks.json` — LLVM pass remarks from the pipeline (optional)

When a **dataset** is selected from the top-left dropdown, fetch paths are prefixed with that folder (e.g. `datasets/loop-tiling/`). Curated entries are **static snapshots**; pipeline outputs from `run_pipeline.sh` or `analyze.sh` normally land in `web/` root — copy into `web/datasets/<name>/` to list them in the dropdown (see **FEATURES.md**).

**Regenerating selected datasets without hand-editing JSON:** use **`scripts/build_dataset_loop_split_openmp.sh`** (host `perf` via **`run-perf.sh`**) and **`scripts/build_dataset_amdgpu_loop_unroll.sh`** (GPU **`rocprof-compare-bins.sh`** when ROCm is available). Both run **`ll-dump`** and only write **`perf_compare.json`** through those profiler scripts — see **`testcases/README.md`**.

### 3b. What is offline vs. what calls an API

| Stage | Offline? |
|-------|----------|
| `run_pipeline.sh`, `ll-dump`, `run-perf.sh`, serving static files | Yes (needs Linux + LLVM build for extraction; `perf` optional) |
| CFG, diff, morph, instruction mix, memory view, dependencies, perf chart | Yes (browser JS only) |
| Auto-detect transform badge | Yes |
| Insight Engine (8 signals, 10 rules, bottleneck classification) | Yes (browser JS only) |
| Chat with no AI configured | Yes (rule engine + keyword answers) |
| Insights / Chat with provider configured | Calls your chosen API (or local Ollama); on error, falls back to rules |

### 4. Data processing (JavaScript)

- **CFG construction**: nodes and edges are processed into D3 data arrays. Loop membership is computed per-node by matching block labels against each loop's `blocks` array. Each node stores its innermost loop reference.
- **Back-edge detection**: edges whose target is a loop header and whose source is within that loop are marked as back-edges (rendered with dashed lines).
- **Diff computation**: when both before and after are loaded, block labels are compared. Blocks present only in "before" are marked `removed`; only in "after" are marked `added`. Shared blocks are `unchanged`.
- **Performance normalization**: all metrics are normalized to before=1.0 for the grouped bar chart. Direction-aware coloring (green if improved, red if regressed) uses each metric's `lowerBetter` flag.
- **Insight Engine**: Phase 1 (feature extraction, signal computation, rule engine, aggregation) runs deterministically in the browser on the loaded JSON. See [ENGINE.md](ENGINE.md).

### 5. Rendering

- **Force-directed layout**: D3's `forceSimulation` positions nodes with charge repulsion and link forces. Users can drag nodes.
- **Hierarchical layout** (optional): Dagre computes a top-to-bottom layered layout respecting edge direction.
- **Loop regions**: translucent rounded rectangles are drawn around each loop's bounding box, colored by depth.
- **Morph animation**: interpolates node positions from before-CFG coordinates to after-CFG coordinates using D3 transitions, with nodes fading in/out for added/removed blocks.
- **Bar chart**: D3 grouped bar chart with normalized Y-axis, tooltips showing absolute values and percentage change.
- **Insights panel**: uses the Insight Engine's Phase-1 report (signals, rules, bottleneck classification, suggestions). If an AI provider is configured, Phase-2 natural-language explanation is added alongside. See **FEATURES.md** ("Offline vs. AI-Powered Features").

### 6. User interaction

All core interaction is client-side JavaScript:

- **Node click** → side panel populates with instruction mix bar, memory access visualization (read/write ratio, per-array cards, locality animation), and dependency chips.
- **Hover** → tooltip follows cursor showing block name, loop membership, and diff status.
- **Play** → loop animation steps through basic blocks in topological order within the selected loop, highlighting the active block and showing memory access chips.
- **⚙ AI / ✨ Insights / 💬 Chat** → optional LLM integration (step-by-step in **FEATURES.md**); no network required for rule-based fallbacks.

## Script Reference

| Script | Purpose |
|--------|---------|
| `run_pipeline.sh` | Primary entry point: C source → full pipeline → serve |
| `scripts/analyze.sh` | From pre-existing `.ll` → `ll-dump` + profiler + serve |
| `scripts/run-perf.sh` | CPU profiling: compile `.ll`, run N times with `perf stat` → `perf_compare.json` |
| `scripts/run-rocprof.sh` | GPU profiling: compile `.ll` for amdgcn, run with `rocprof` → `perf_compare.json` |
| `scripts/rocprof-compare-bins.sh` | GPU profiling for pre-linked executables |
| `scripts/run-transform.sh` | Apply a single LLVM pass to `.ll` (used by other scripts) |
| `scripts/parse-remarks.py` | Convert LLVM YAML remarks → JSON for the UI |
| `scripts/build_dataset_loop_split_openmp.sh` | Regenerate `loop-split-openmp` dataset |
| `scripts/build_dataset_amdgpu_loop_unroll.sh` | Regenerate `amdgpu-loop-unroll` dataset |
| `scripts/cursor_agent_proxy.py` | CORS proxy for Cursor Cloud Agents API |
