# Test cases

## Loop tiling (`loop_tiling_before.ll` / `loop_tiling_after.ll`)

- **Before:** one counted loop over `i`, load/add/store on `A[i]`.
- **After:** same logic with a fixed tile size of **4**: outer induction `t`, inner `i` within `[t, min(t+4, N))`.

Both define `void @tile_demo(ptr %A, i32 %N)` so the viewer’s **Show diff** mode can compare the same function name.

### Generate JSON and view

From the repository root (after `make`):

```bash
./ll-dump testcases/loop_tiling_before.ll -o web/before.json
./ll-dump testcases/loop_tiling_after.ll -o web/after.json
cd web && python3 -m http.server 8765
```

Open the app, enable **Show diff**, choose **`tile_demo`**. Red/green blocks show CFG changes; the animation bar (single view only) can step each version separately if you load one file as `output.json`.

Or run:

```bash
testcases/run_loop_tiling_view.sh
```

which writes `web/before.json` and `web/after.json` and prints the same `python3 -m http.server` hint.

### Performance overlay (`perf.json`)

The viewer loads optional **`web/perf.json`** next to `index.html`. It attaches **cycles**, **instructions**, **ipc** (optional; derived from instructions÷cycles when possible), **cache_misses**, and **branch_misses** to loops (by LLVM loop `id` from `output.json` / `before.json` / `after.json`). **Manual numbers are fine**; use real `perf` data when you can map samples to those loop ids.

A top-level **`compare`** object `{ "function": "tile_demo", "before": { ... }, "after": { ... } }` (function optional; when set it must match the selected function) drives **D3** bar charts: whole-function before/after metrics, IPC comparison, and a per-loop **cache miss** distribution in diff mode (or single-graph loops when diff is off).

**Loop ids for this tiling example** (from `ll-dump`):

| IR | Loop id | Header |
|----|---------|--------|
| `loop_tiling_before.ll` | `tile_demo::loop::0` | `loop` |
| `loop_tiling_after.ll` | `tile_demo::outer::0` | `outer` |
| `loop_tiling_after.ll` | `tile_demo::inner::1` | `inner` |

**Quick path — diff + perf:**

```bash
./ll-dump testcases/loop_tiling_before.ll -o web/before.json
./ll-dump testcases/loop_tiling_after.ll -o web/after.json
cp testcases/perf.loop_tiling.example.json web/perf.json
cd web && python3 -m http.server 8765
```

Open **http://127.0.0.1:8765/** → **Show diff** → **`tile_demo`**. The **before** panel uses `tile_demo::loop::0`; the **after** panel uses `tile_demo::outer::0` and `tile_demo::inner::1`. Edit **`web/perf.json`** with your own numbers; **redder / stronger** loop shading = more cache misses (scaled per side). Hover the chart bars for short metric explanations.

**Single-graph perf** (tiled IR only):

```bash
./ll-dump testcases/loop_tiling_after.ll -o web/output.json
cp testcases/perf.loop_tiling.example.json web/perf.json
# Optional: remove the tile_demo::loop::0 entry from perf.json — it only matches the before CFG
cd web && python3 -m http.server 8765
```

Leave **Show diff** off. Only keys that match loops in the loaded JSON are used.

**Using real `perf`:** record your binary (e.g. `perf record -e cycles,cache-misses ./a.out`), then attribute hot regions to source/LLVM loops (e.g. `perf report`, scripts, or LLVM line tables) and **paste** representative totals into `by_loop_id` for the ids above. The UI does not run `perf` for you.

## Other samples

- `matrix_traversal.c` — compile to `.ll` with Clang (`-S -emit-llvm`) if you want a larger CFG for experiments.
