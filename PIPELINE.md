# How the Tool Works

## Pipeline Overview

```
LLVM IR (.ll)           Linux perf (optional)
     │                      │
     ▼                      ▼
  ll-dump             run-perf.sh → perf_compare.json
     │                      │
     ▼                      │
 before.json / after.json   │
 (instruction mix, deps,     │
  memory patterns)           │
     │                      │
     └──────┬───────────────┘
            ▼
     index.html (browser) — 100% offline rendering
            │
            ├── Rule-based insights & keyword chat (always available)
            │
            └── Optional: ⚙ AI → external LLM (OpenAI / Anthropic / Ollama / custom)
                        for richer ✨ Insights and 💬 Chat (falls back on failure)
```

**One-command path:** `./scripts/analyze.sh before.ll after.ll` builds `ll-dump` if needed, runs `ll-dump` on both IRs into `web/before.json` and `web/after.json`, runs `scripts/run-perf.sh` when `perf` exists, then serves `web/` with Python’s HTTP server.

## Step-by-Step

### 1. IR → JSON extraction (`ll-dump`)

The `ll-dump` tool (C++, linked against LLVM libraries) parses an `.ll` file and extracts:

- **Per-function CFG**: basic block nodes with IDs and labels, edges with source/target (including back-edges).
- **Loop analysis**: runs LLVM's `LoopInfoWrapperPass` to identify loop headers, depths, blocks, and trip counts via `ScalarEvolution`.
- **Instruction counts**: total and per-category (arithmetic, memory, branch, other) for each basic block.
- **Memory accesses**: array name, access pattern (stride-1 or strided), and type (load/store) for each loop.
- **Dependencies**: type (loop-carried, flow, anti, output), variable names, distance, and description.

Output: a single JSON file per IR file.

### 2. Performance data (manual or scripted)

`perf_compare.json` is a JSON object with `before` and `after` fields containing hardware counter measurements:

- `runs` — number of `perf stat` iterations (default 5); displayed in the chart heading
- `execution_time`, `cycles`, `instructions`, `ipc`
- `l1_miss_rate`, `llc_miss_rate`, `branch_miss_rate`

Optionally includes `transform_insights` with structured explanations of why metrics changed.

This file is produced by `scripts/run-perf.sh` (invoked from `analyze.sh` or manually) or hand-authored. By default `perf stat -r 5` is used, so every counter is the average of 5 runs; override with `PERF_RUNS=N`. The `"runs"` field in the JSON is displayed in the UI heading. Without this file, charts and some insight text are omitted; the CFG and node panels still work.

### 3. Browser loads JSON

On page load, `index.html` fetches JSON relative to the page (or under a dataset prefix). Typical files:

1. `output.json` — single-view CFG (optional)
2. `before.json` / `after.json` — comparison pair (optional)
3. `perf_compare.json` — before/after hardware counters for the bar chart (optional)
4. `perf.json` — legacy per-loop performance overlay (optional)

When a **dataset** is selected from the top-left dropdown, fetch paths are prefixed with that folder (e.g. `datasets/loop-tiling/`). The default curated entries are static reference data; your own runs can be saved under `web/datasets/<name>/` and registered as new `<option>`s — see **FEATURES.md** (“Dataset Dropdown”).

### 3b. What is offline vs. what calls an API

| Stage | Offline? |
|-------|----------|
| `ll-dump`, `run-perf.sh`, serving static files | Yes (needs Linux + LLVM build for extraction; `perf` optional) |
| CFG, diff, morph, instruction mix, memory view, dependencies, perf chart | Yes (browser JS only) |
| Auto-detect transform badge | Yes |
| ✨ Insights / 💬 Chat with no AI configured | Yes (rule engine + keyword answers) |
| ✨ Insights / 💬 Chat with provider configured | Calls your chosen API (or local Ollama); on error, falls back to rules |

### 4. Data processing (JavaScript)

- **CFG construction**: nodes and edges are processed into D3 data arrays. Loop membership is computed per-node by matching block labels against each loop's `blocks` array. Each node stores its innermost loop reference.
- **Back-edge detection**: edges whose target is a loop header and whose source is within that loop are marked as back-edges (rendered with dashed lines).
- **Diff computation**: when both before and after are loaded, block labels are compared. Blocks present only in "before" are marked `removed`; only in "after" are marked `added`. Shared blocks are `unchanged`.
- **Performance normalization**: all metrics are normalized to before=1.0 for the grouped bar chart. Direction-aware coloring (green if improved, red if regressed) uses each metric's `lowerBetter` flag.

### 5. Rendering

- **Force-directed layout**: D3's `forceSimulation` positions nodes with charge repulsion and link forces. Users can drag nodes.
- **Hierarchical layout** (optional): Dagre computes a top-to-bottom layered layout respecting edge direction.
- **Loop regions**: translucent rounded rectangles are drawn around each loop's bounding box, colored by depth.
- **Morph animation**: interpolates node positions from before-CFG coordinates to after-CFG coordinates using D3 transitions, with nodes fading in/out for added/removed blocks.
- **Bar chart**: D3 grouped bar chart with normalized Y-axis, tooltips showing absolute values and percentage change.
- **Insights panel (benchmark area)**: uses `transform_insights` from JSON when present; otherwise the UI can still show metric-derived summaries. The **✨ Insights** button adds a separate panel fed by either an LLM (if configured in **⚙ AI**) or the built-in **rule-based** engine — see **FEATURES.md** (“Offline vs. AI-Powered Features”).

### 6. User interaction

All core interaction is client-side JavaScript:

- **Node click** → side panel populates with instruction mix bar, memory access visualization (read/write ratio, per-array cards, locality animation), and dependency chips.
- **Hover** → tooltip follows cursor showing block name, loop membership, and diff status.
- **Play** → loop animation steps through basic blocks in topological order within the selected loop, highlighting the active block and showing memory access chips.
- **⚙ AI / ✨ Insights / 💬 Chat** → optional LLM integration (step-by-step in **FEATURES.md**); no network required for rule-based fallbacks.
