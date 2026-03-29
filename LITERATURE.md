# Related Work & Comparison

A survey of existing compiler visualization tools and how this tool differs.

**Offline vs. AI in this tool:** CFGs, loop analysis, instruction mix, memory-access patterns, dependencies, `perf_compare.json` charts, auto-detected transform labels, and **rule-based** insights/chat all run in the browser without any LLM. **AI** (OpenAI, Anthropic, Ollama, or a custom OpenAI-compatible endpoint) is optional and only upgrades the ✨ Insights and 💬 Chat panels; see **FEATURES.md** for the full offline table and step-by-step AI setup.

---

## 1. LLVM `opt -view-cfg` / Graphviz

LLVM's built-in CFG viewer renders basic blocks as a static Graphviz DOT graph, opened in an external viewer (xdot, Preview, etc.).

- **What it does**: Static CFG image from a single IR file. No interactivity, no comparison.
- **Our advantage**: Interactive (zoom, drag, click nodes), side-by-side before/after diff with morph animation, loop-aware coloring, and integrated performance metrics — all in a browser with no desktop dependencies.

## 2. Compiler Explorer (godbolt.org)

The most popular compiler tool on the web. Compiles source to assembly in real-time with source-to-assembly line mapping. Supports 3000+ compilers and 81 languages.

- **What it does**: Source → assembly mapping, optional CFG view (via `-emit-cfg`), multiple compiler comparison. Focus is on generated assembly, not on understanding specific optimizer transforms.
- **Our advantage**: Designed specifically for loop transformations. Shows *what changed* between before/after (diff, morph), *why it changed* (dependency analysis, memory access patterns), and *what the performance impact was* (benchmark bar chart, cache/IPC/branch metrics, "why did this help" panel). Compiler Explorer shows none of these.

## 3. llvm-flow (kc-ml2)

An open-source web tool for comparing IR CFGs interactively. Allows side-by-side comparison of two IR files.

- **What it does**: Parses LLVM IR in-browser, renders two CFGs side by side, highlights matching/differing blocks.
- **Our advantage**: Goes beyond structural diff — adds loop analysis (depth, trip count, induction variables), per-block instruction mix visualization, memory access pattern analysis with locality indicators, dependency information, performance benchmarking integration, and animated loop execution stepping. llvm-flow shows structure only; we show structure + semantics + performance.

## 4. LLVM opt-viewer / optview2

Renders LLVM optimization remarks as annotated HTML. Each source line shows which optimizations fired or failed and why.

- **What it does**: Source-level annotation of optimization decisions. Good for understanding *why* the compiler did or didn't vectorize a loop, inline a function, etc.
- **Our advantage**: Complementary scope — opt-viewer explains the compiler's decision process; we visualize the *result* of those decisions on the CFG and performance. We provide interactive graphs instead of static annotated source, and include quantitative performance comparison.

## 5. CcNav (LLNL)

A web-based tool for visualizing compiler optimizations in binaries, developed at Lawrence Livermore National Laboratory.

- **What it does**: Maps binary-level optimizations back to source, showing inlining decisions, loop transforms, and vectorization at the object code level.
- **Our advantage**: CcNav works post-compilation on binaries, which is useful for production analysis but loses IR-level structure. Our tool operates at the IR level where loop structure, trip counts, and memory patterns are explicit and inspectable. We also provide animated morph transitions and integrated perf metric comparison.

## 6. CFGConf / VEIL (Research)

Academic layout algorithms for CFG rendering. CFGConf provides a JSON-based CFG drawing library; VEIL uses dominator analysis for execution-order-preserving layout.

- **What they do**: Better graph layout algorithms for CFGs — addressing the problem that Graphviz's general-purpose `dot` layout often breaks natural execution flow.
- **Our advantage**: We use both force-directed and Dagre hierarchical layout (user's choice), but our contribution is not the layout algorithm — it's the full analysis stack: loop semantics, memory patterns, dependency chains, and performance metrics layered on top of the CFG.

## 7. llvmcfg (dhy2000)

Converts LLVM IR CFGs to Mermaid diagram format for embedding in Markdown.

- **What it does**: Simple IR → Mermaid conversion for documentation.
- **Our advantage**: Full interactive visualization with zoom, drag, animation, diff, performance data — versus a static Markdown diagram.

## 8. LLVM IR to CFG Visualizer (kakudo.org)

A web tool where you paste LLVM IR and get a rendered CFG.

- **What it does**: Paste IR → see CFG. Lightweight, no installation.
- **Our advantage**: Supports before/after comparison, loop-aware analysis, performance benchmarking, animated transitions, and pre-built datasets for common transformations. The kakudo tool is a single-shot visualizer with no analysis capability.

---

## Coverage: LLVM Transform Levels

| Transform level | Examples | This tool |
|----------------|----------|-----------|
| **Middle-end IR passes** | LoopUnroll, LoopInterchange, LoopFuse, LoopDistribute, LoopFlatten, LoopVectorize, LICM, Polly | **Full support** — compare before/after `.ll` files |
| **OpenMP/Clang AST pragmas** | `#pragma omp tile/unroll/interchange/fuse/split` | **Indirect** — shows effect on emitted IR, not AST restructuring |
| **Backend / MachineIR** | Software pipelining, hardware loops | Not supported (`.mir` not parsed) |

---

## Summary

| Capability | opt -view-cfg | Godbolt | llvm-flow | opt-viewer | CcNav | **This tool** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Interactive CFG | — | partial | yes | — | yes | **yes** |
| Before/after diff | — | — | yes | — | — | **yes** |
| Morph animation | — | — | — | — | — | **yes** |
| Loop analysis | — | — | — | — | — | **yes** |
| Memory access patterns | — | — | — | — | — | **yes** |
| Dependency visualization | — | — | — | — | — | **yes** |
| Performance metrics | — | — | — | — | partial | **yes** |
| "Why did this help" insights | — | — | — | partial | — | **yes** |
| Instruction mix per block | — | — | — | — | — | **yes** |
| Loop execution animation | — | — | — | — | — | **yes** |
| Auto-detect transform type | — | — | — | — | — | **yes** |
| Integrated perf profiling | — | — | — | — | — | **yes** |
| AI-powered insights (optional LLM) | — | — | — | — | — | **yes** |
| Interactive AI chatbot (optional LLM) | — | — | — | — | — | **yes** |
| Rule-based insights / chat (no API) | — | — | — | — | — | **yes** |
| Full visualization offline (no AI / no cloud) | — | partial | partial | — | — | **yes** |
| Browser-based, zero install | — | yes | yes | — | yes | **yes** |
| Middle-end IR transforms | — | — | partial | yes | — | **yes** |
| OpenMP AST transforms (indirect) | — | — | — | — | — | **yes** |


