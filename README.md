# LLVM Loop Transform Visualiser

Interactive, browser-based visualization of **before/after LLVM IR** for loop transformations: CFG diff, loop analysis (LLVM `LoopInfo` / `ScalarEvolution` / `DependenceInfo`), memory-access patterns, optional **CPU** (`perf stat`) or **GPU** (`rocprof`) benchmarks, critical-path highlighting, optimization remarks, and optional **LLM**-powered insights and chat.

## Fully automated pipeline (C source → visualization)

A single command takes a C/C++ source file, compiles it, applies an LLVM optimization pass, and produces all artifacts dynamically — no precomputed data, no manual steps:

```bash
./run_pipeline.sh input.c loop-unroll
```

What happens (zero manual/AI steps):

1. **`clang`** compiles C/C++ → clean-SSA LLVM IR (`before.ll`).
2. **`opt -passes=<PASS>`** applies the transformation → `after.ll`.
3. **`ll-dump`** parses both IRs → `web/before.json` and `web/after.json` (CFG, loops, instruction mix, dependencies, memory patterns, block cost / impact, critical path).
4. **`perf stat`** or **`rocprof`** (auto-detected from IR triple, or `PROFILER=`) runs the binaries and writes **`web/perf_compare.json`** (averaged over 5 runs by default).
5. **`opt`** emits optimization remarks → `web/remarks.json`.
6. **HTTP server** serves the visualization at `http://localhost:8765/`.

LLVM tools (`clang`, `opt`, `llvm-config`) are **auto-detected** from a sibling `llvm-project/build/` directory or `PATH`.

### From pre-existing IR files

If you already have `.ll` files, use `analyze.sh` directly:

```bash
./scripts/analyze.sh path/to/before.ll path/to/after.ll
```

The **dataset dropdown** is optional: it ships **curated** JSON under `web/datasets/` for demos and teaching. Those files are **not** regenerated when you change IR; for a fully automated path, use `run_pipeline.sh` or `analyze.sh` and the outputs appear in `web/`. Copy them into `web/datasets/<name>/` for a saved snapshot. See **FEATURES.md** ("Dataset dropdown") for details.

## Quick start

```bash
git clone <repo-url>
cd llvm-loop-transform-visualiser
./run_pipeline.sh testcases/gpu_reduction.c loop-unroll       # GPU kernel (amdgcn)
./run_pipeline.sh testcases/jacobi_stencil.c licm             # CPU stencil
```

Opens a local server (default port **8765**) and loads the generated JSON. Requires **LLVM** (`llvm-config` on `PATH` or `make LLVM_CONFIG=…`). On Linux, **`perf`** or **`rocprof`** (ROCm) improves the benchmark panel but is optional.

## Documentation

| File | Contents |
|------|----------|
| [ENGINE.md](ENGINE.md) | Insight Engine architecture: 3 phases, 8 signals, 10 rules |
| [FEATURES.md](FEATURES.md) | Full feature list, offline vs AI, dataset dropdown, AI provider setup |
| [PIPELINE.md](PIPELINE.md) | Data flow: C source → IR → JSON → perf/rocprof → browser |
| [VISUALS.md](VISUALS.md) | Hands-on usage, troubleshooting |
| [LITERATURE.md](LITERATURE.md) | Comparison with related tools |
| [testcases/README.md](testcases/README.md) | Example testcases and manual `ll-dump` / perf steps |

## Build only the extractor

```bash
make                    # or: make LLVM_CONFIG=/path/to/llvm-config
./ll-dump file.ll -o web/output.json
```

## Optional AI (insights and chat)

The UI supports **OpenAI**, **Anthropic**, **Ollama** (local), **custom** OpenAI-compatible URLs, and **Cursor Cloud Agents** (Cursor API key + local `scripts/cursor_agent_proxy.py`—see **FEATURES.md**). **Cursor Pro** IDE quota is not a separate HTTP API for this page; use OpenAI/Anthropic keys or the Cloud Agents path documented there.

## License / contributing

See repository defaults (add `LICENSE` if missing). Contributions welcome: regenerating curated datasets from real `run_pipeline.sh` or `analyze.sh` runs improves demo fidelity.
