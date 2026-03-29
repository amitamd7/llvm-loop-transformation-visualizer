# How to Use This Tool

This file is the hands-on guide; **FEATURES.md** lists capabilities, offline vs. AI behavior, dataset dropdown semantics, and AI setup steps. **PIPELINE.md** describes data flow end-to-end.

## Prerequisites

- LLVM built with `llvm-config` on `PATH` (or set `LLVM_CONFIG`).
- Python 3 (for local HTTP server).
- A web browser.
- Linux `perf` (optional) for automated `perf_compare.json` via `scripts/run-perf.sh`.

## Quick Start (pre-built datasets)

```bash
cd web
python3 -m http.server 8765
```

Open **http://localhost:8765/**. Use the **transformation dropdown** (top-left) to switch between curated examples (Loop Tiling, Unrolling, Interchange, Fusion, LICM, IR-derived tiling, etc.). Those entries load **static JSON** under `web/datasets/…` — useful for demos and teaching without building LLVM IR. To compare **your** transforms from the dropdown, save outputs under `web/datasets/<name>/` and add an `<option>` in `index.html` (see **FEATURES.md**).

## Full pipeline (recommended)

From the repo root, with two IR files:

```bash
./scripts/analyze.sh path/to/before.ll path/to/after.ll
```

This builds `ll-dump` if missing, writes `web/before.json` and `web/after.json` (including per-block instruction mix and loop dependencies), runs `perf stat` when available to produce `web/perf_compare.json`, then starts the HTTP server. **No AI is required** — every visualization works offline.

## From Your Own LLVM IR (manual steps)

### 1. Build the JSON extractor

```bash
make LLVM_CONFIG=/path/to/llvm-config
```

### 2. Generate JSON from IR

**Single file:**

```bash
./ll-dump your_file.ll -o web/output.json
```

**Before/after comparison:**

```bash
./ll-dump before.ll -o web/before.json
./ll-dump after.ll  -o web/after.json
```

### 3. Add performance data (optional)

**Automated (Linux):**

```bash
./scripts/run-perf.sh before.ll after.ll web/
```

**Hand-written** `web/perf_compare.json`:

```json
{
  "before": { "execution_time": 120, "cycles": 3200000000, "ipc": 2.81, "l1_miss_rate": 2.8 },
  "after":  { "execution_time": 80,  "cycles": 2600000000, "ipc": 3.0,  "l1_miss_rate": 1.8 }
}
```

### 4. Serve and open

```bash
cd web && python3 -m http.server 8765
```

Open **http://localhost:8765/** in your browser.

### 5. Interact

| Action | How |
|--------|-----|
| Switch transformation / dataset | Top-left dropdown (curated library or your saved `web/datasets/…` folders) |
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
| AI insights & chat (optional) | **⚙ AI** to set provider, then **✨ Insights** / **💬 Chat** — full steps in **FEATURES.md** |

## From C Source

```bash
clang -S -emit-llvm -O0 -fno-discard-value-names your.c -o before.ll
clang -S -emit-llvm -O2 -fno-discard-value-names your.c -o after.ll
./ll-dump before.ll -o web/before.json
./ll-dump after.ll  -o web/after.json
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Blank page / "No JSON found" | Ensure JSON files exist in `web/` (or under the dataset path selected in the dropdown) and the server was started from `web/`. |
| Show diff grayed out | Both `before.json` and `after.json` must exist and share at least one function name. |
| Port in use | Use another port: `PORT=8766 ./scripts/analyze.sh …` or `python3 -m http.server 8766`. |
| `ll-dump` link failure | Verify `LLVM_CONFIG` points to the correct LLVM build. |
| No perf bar chart | `perf` missing or `run-perf.sh` failed — charts need `perf_compare.json`; CFG still loads. |
| AI chat / insights errors | Check API key and endpoint in **⚙ AI**; the app falls back to rule-based text if the call fails. |
