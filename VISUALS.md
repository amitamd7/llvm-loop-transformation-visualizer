# How to produce the CFG visuals

You get an **interactive CFG** (D3: zoom, drag blocks, function switcher) from LLVM IR via JSON and **`web/index.html`**. This document walks through the process **from scratch** using a concrete example, then summarizes variants.

## Prerequisites

- LLVM with `llvm-config` on your `PATH`, **or** set `LLVM_CONFIG` to your build’s `llvm-config` (e.g. `…/llvm-project/build/bin/llvm-config`).
- A normal shell, `make`, and Python 3 (for the local HTTP server).

---

## Step-by-step from scratch (example: loop tiling)

Use the bundled **`testcases/loop_tiling_before.ll`** and **`testcases/loop_tiling_after.ll`**. Both define the same function name **`tile_demo`**, which is what the **diff** viewer expects on the left and right.

### Step 1 — Open a terminal in the project root

```bash
cd /path/to/llvm-loop-transform-visualiser
```

Replace `/path/to/llvm-loop-transform-visualiser` with your actual clone path.

### Step 2 — Build `ll-dump`

```bash
make LLVM_CONFIG=/path/to/llvm-config
```

If `llvm-config` is already on your `PATH`, run **`make`** with no arguments.

You should get an executable **`./ll-dump`** in the project root. If the linker fails, double-check `LLVM_CONFIG` points at the same LLVM tree you built.

### Step 3 — Emit JSON for the “before” IR

```bash
./ll-dump testcases/loop_tiling_before.ll -o web/before.json
```

You should see a line like **`Wrote web/before.json`**. That file lists functions (including **`tile_demo`**) with CFG nodes/edges, loops, and optional memory metadata.

### Step 4 — Emit JSON for the “after” (tiled) IR

```bash
./ll-dump testcases/loop_tiling_after.ll -o web/after.json
```

Again, confirm **`Wrote web/after.json`**.

### Step 5 — Start a local web server in `web/`

Browsers restrict **`fetch()`** for arbitrary local files under **`file://`**, so the page must be served over HTTP.

```bash
cd web && python3 -m http.server 8765
```

Leave this terminal open. If port **8765** is busy, pick another (e.g. **8766**) and use that port in the URL below.

Alternatively, from the repo root, **`make web-serve`** copies a root-level **`output.json`** into **`web/`** if present, then starts a server on **8765** (same **`cd web && python3 …`** pattern).

### Step 6 — Open the viewer in a browser

Go to:

**http://127.0.0.1:8765/**

(or **http://localhost:8765/**)

### Step 7 — Use the UI

- **Function:** choose **`tile_demo`** (it appears in the list because both JSON files define it).
- **Show diff:** turn **on** to see **Before** and **After** side by side. Blocks that exist only in one file are tinted **red** (removed vs the other side) or **green** (new). The small table compares loop count, block count, and instruction count.
- **Single graph:** turn **Show diff** **off** to see one CFG. The tool prefers **`output.json`** if present; otherwise it falls back to **`before.json`** or **`after.json`**. For a single view of only the tiled IR, either copy **`web/after.json`** to **`web/output.json`** or run  
  **`./ll-dump testcases/loop_tiling_after.ll -o web/output.json`**  
  and reload with diff off.
- **Pan / zoom / drag:** scroll to zoom, drag the background to pan, drag nodes to rearrange.
- **Loop animation (single view only):** with diff off and a function that has loops, use **Play** / **Pause**, the **Speed** slider, and the **Loop** dropdown. Memory chips show patterns like **`A[i]`** when the JSON includes **`memory_accesses`** for that loop.

### Step 8 — Optional one-shot script

From the repo root:

```bash
./testcases/run_loop_tiling_view.sh
```

This runs **`ll-dump`** on both tiling files and writes **`web/before.json`** and **`web/after.json`**, then prints the same **`cd web && python3 -m http.server …`** hint.

---

## Shorter path (single file, no diff)

If you only want one CFG and no comparison:

1. **Build** (Step 2 above).
2. **`./ll-dump test/sample.ll -o web/output.json`**
3. **`cd web && python3 -m http.server 8765`**
4. Open **http://127.0.0.1:8765/**, leave **Show diff** off, pick a function (e.g. **`array_walk`**) in the menu.

---

## Bringing your own `.ll`

1. Produce LLVM IR (**`.ll`**) from C/C++ with Clang, e.g.  
   **`clang -S -emit-llvm -O1 -fno-discard-value-names your.c -o your.ll`**,  
   or use IR you already have.
2. Run **`./ll-dump your.ll -o web/output.json`** (or **`-o web/before.json` / `web/after.json`** for two versions of the “same” logical change).
3. Serve **`web/`** and open the page as above.

---

## Troubleshooting

| Issue | What to try |
|--------|----------------|
| Blank or “No JSON found” | Ensure **`web/output.json`** and/or **`web/before.json` + `web/after.json`** exist and the server was started from **`web/`** or can see those paths. |
| **Show diff** disabled / grayed | Both **`before.json`** and **`after.json`** must load successfully and share at least one function name. |
| Port in use | Use another port: **`python3 -m http.server 8766`** and open that port in the browser. |
| **`ll-dump` fails to link** | Point **`LLVM_CONFIG`** at the **`llvm-config`** from the LLVM build you intend to use. |

---

## Summary

**Full tiling example:**  
`make` → **`./ll-dump testcases/loop_tiling_before.ll -o web/before.json`** → **`./ll-dump testcases/loop_tiling_after.ll -o web/after.json`** → **`cd web && python3 -m http.server 8765`** → open **http://127.0.0.1:8765/** → **Show diff** → **`tile_demo`**.

**Minimal single CFG:**  
`make` → **`./ll-dump test/sample.ll -o web/output.json`** → serve **`web/`** → open the URL → pick a function.
