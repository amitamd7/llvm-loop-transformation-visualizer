# Insight Engine — Architecture

> Deterministic, explainable analysis of LLVM IR loop transformations.

---

## Overview

The Insight Engine is a **three-phase** system that takes `(before-IR, after-IR, perf-metrics)` as input and produces structured, explainable insights about what changed and why.

```
Phase 1 (mandatory)    Phase 2 (optional)      Phase 3 (research)
────────────────────   ────────────────────     ────────────────────
  FeatureExtractor       LLMExplainer             MLModel
        ↓                     ↑                      ↑
  SignalComputer        reads Phase-1 report    trained on Phase-1
        ↓                     ↓                  feature vectors
    RuleEngine          natural-language              ↓
        ↓               explanation            bottleneck prediction
  InsightAggregator                            (separate output)
        ↓
   Structured Report (JSON)
```

**Key invariant:** Phase 2 and 3 never override Phase 1.  The rule-based report is the single source of truth.

---

## Phase 1 — Rule-Based + Scoring Engine

### Module 1: FeatureExtractor

**File:** `web/insight-engine/feature-extractor.js`

**Input:** `ll-dump` JSON (`{functions: [...]}`) + perf_compare.json

**Output:** `FeatureVector`

```json
{
  "loop": {
    "count": 2,
    "max_depth": 2,
    "known_trip_counts": [256],
    "mean_trip_count": 256,
    "has_unknown_trip": true,
    "dependency_count": 3,
    "loop_carried_count": 1,
    "memory_access_count": 4,
    "stride1_fraction": 0.75,
    "strided_fraction": 0.25,
    "unknown_pattern_fraction": 0,
    "load_count": 3,
    "store_count": 1,
    "read_write_ratio": 0.75,
    "unique_arrays": 3
  },
  "instruction": {
    "total": 42,
    "arith_fraction": 0.45,
    "memory_fraction": 0.35,
    "branch_fraction": 0.12,
    "other_fraction": 0.08
  },
  "cfg": {
    "block_count": 6,
    "edge_count": 8,
    "back_edge_count": 2,
    "max_block_cost": 12,
    "total_cost": 38,
    "critical_path_cost": 24
  },
  "performance": {
    "execution_time": 1.234,
    "cycles": 4500000,
    "instructions": 3200000,
    "ipc": 0.71,
    "l1_miss_rate": 12.3,
    "branch_miss_rate": 2.1
  }
}
```

The `extractPair(beforeIR, afterIR, perfJSON)` function returns `{before, after, meta}` where `meta` includes `{is_gpu, profiler, device, runs}`.

---

### Module 2: SignalComputer

**File:** `web/insight-engine/signal-computer.js`

**Input:** `FeatureVector` + `is_gpu` flag

**Output:** `SignalVector` — eight continuous signals in [0, 1]

| Signal | Meaning | Higher is… | Formula summary |
|--------|---------|-----------|-----------------|
| `locality` | Spatial locality quality | better | 0.6×stride1 + 0.4×(1−L1miss%) |
| `cache_efficiency` | Cache hierarchy utilisation | better | harmonic_mean(1−L1%, 1−LLC%) |
| `parallelism` | ILP / GPU occupancy | better | IPC/6 (CPU) or waves/1024 (GPU) |
| `vectorization` | Compute density / SIMD-ness | better | 0.7×arith_frac + 0.3×(1−branch_frac) |
| `memory_pressure` | Memory-boundedness | **worse** | mem_inst_frac + miss_contribution |
| `branch_overhead` | Branch stall cost | **worse** | branch_miss_rate/100 |
| `loop_complexity` | Loop nest complexity | **worse** | depth/4 + dep_density + unknowns |
| `critical_path_dominance` | Hot-path concentration | neutral | crit_path_cost / total_cost |

`computePair(featurePair)` returns `{before, after, delta}` where `delta[k] = after[k] − before[k]`.

---

### Module 3: RuleEngine

**File:** `web/insight-engine/rule-engine.js`

Rules are stateless functions registered in a list.  Each rule:

```
(signals: {before, after, delta}, features: {before, after, meta}) → Insight[] | null
```

**Insight schema:**

```json
{
  "id": "locality_change",
  "type": "locality",
  "direction": "improved",
  "confidence": 0.82,
  "impact": "high",
  "summary": "Spatial locality improved (Δ=+0.274)",
  "evidence": {
    "before_locality": 0.412,
    "after_locality": 0.686,
    "delta": 0.274,
    "l1_miss_before": 18.3,
    "l1_miss_after": 5.1
  }
}
```

**Built-in rules** (10 rules, extensible via `registerRule(fn)`):

| Rule | Trigger | Maps to signal |
|------|---------|----------------|
| `locality_change` | \|Δlocality\| ≥ 0.03 | locality |
| `cache_efficiency_change` | \|Δcache_eff\| ≥ 0.03 | cache_efficiency |
| `parallelism_change` | \|Δparallelism\| ≥ 0.02 | parallelism |
| `memory_pressure_change` | \|Δmem_pressure\| ≥ 0.03 | memory_pressure |
| `branch_overhead_change` | \|Δbranch\| ≥ 0.02 | branch_overhead |
| `vectorization_change` | \|Δvectorization\| ≥ 0.03 | vectorization |
| `loop_complexity_change` | \|Δcomplexity\| ≥ 0.05 | loop_complexity |
| `execution_speedup` | \|Δtime\| ≥ 1% | perf.execution_time |
| `instruction_count_change` | \|Δinstr\| ≥ 2% | instruction.total |
| `critical_path_shift` | \|Δcrit_dom\| ≥ 0.05 | critical_path_dominance |

**No rule references a transformation name.** Rules describe *what changed*, not *which pass ran*.

---

### Module 4: InsightAggregator

**File:** `web/insight-engine/insight-aggregator.js`

**Input:** `Insight[]` + `SignalVector pair`

**Output:** `AggregatedReport`

```json
{
  "behaviour": "improved",
  "bottleneck": { "class": "memory-bound", "score": 0.62 },
  "expected": ["poor baseline locality — tiling or interchange could help"],
  "suggestions": ["Memory pressure increased ..."],
  "overall_confidence": 0.71,
  "counts": { "improved": 4, "regressed": 1, "neutral": 0 },
  "improved": [ /* Insight[] */ ],
  "regressed": [ /* Insight[] */ ],
  "neutral": [ /* Insight[] */ ],
  "signals": { "before": {…}, "after": {…}, "delta": {…} },
  "features": { "before": {…}, "after": {…}, "meta": {…} },
  "version": "1.0.0",
  "phase": "rule-based"
}
```

**Bottleneck classification** uses a weighted argmax over anti-signals:

| Anti-signal | Label | Weight |
|-------------|-------|--------|
| memory_pressure | memory-bound | 1.0 |
| branch_overhead | control-flow-bound | 0.8 |
| loop_complexity | loop-complexity-bound | 0.6 |
| vectorization × (1−memory_pressure) | compute-bound | dynamic |

If the highest score < 0.15, classification is `balanced`.

---

### Module 5: Engine (orchestrator)

**File:** `web/insight-engine/engine.js`

Single entry point:

```js
var report = InsightEngine.analyze(beforeIR, afterIR, perfJSON);
```

Internally calls: FeatureExtractor → SignalComputer → RuleEngine → InsightAggregator.

---

## Phase 2 — LLM Explanation Layer

**File:** `web/insight-engine/llm-explainer.js`

The LLM receives the Phase-1 report as context with strict instructions:

1. Do NOT invent insights beyond what the analysis provides.
2. Do NOT contradict rule-engine findings.
3. Explain signals, insights, and bottleneck in compiler-researcher language.
4. Ground suggestions in the provided evidence.

**API:**

```js
// Network call (OpenAI-compatible endpoint)
InsightEngine.LLMExplainer.explain({ endpoint, apiKey, model }, report)
  .then(text => ...);

// Offline fallback (no network)
var text = InsightEngine.LLMExplainer.explainOffline(report);
```

The `buildSystemPrompt()` and `buildUserPrompt(report)` functions are also exported for inspection and paper examples.

---

## Phase 3 — ML Model (skeleton)

**File:** `web/insight-engine/ml-model.js`

### Feature vector

`MLModel.featureVector(features, signals)` flattens all before/after/delta signals plus key structural features into a fixed-size numeric vector (currently 35-dimensional).

### Prediction interface (stub)

```js
InsightEngine.MLModel.predict(vector)
  .then(prediction => {
    // prediction.bottleneck_class  — e.g. "memory-bound" (null in skeleton)
    // prediction.expected_improvement — e.g. 1.23 (null in skeleton)
    // prediction.confidence — 0
    // prediction.source — "ml-model"
    // prediction.status — "skeleton"
  });
```

### Training-data collector

```js
InsightEngine.MLModel.collect(vector, { bottleneck_class: "memory-bound", speedup: 1.5 });
var json = InsightEngine.MLModel.exportData();  // JSON string for offline training
```

### Future: training pipeline

1. Accumulate vectors via `collect()` from real analyses.
2. Export → train XGBoost / RandomForest in Python.
3. Convert to ONNX → load in browser via ONNX.js.
4. ML output displayed alongside (never replacing) Phase-1 report.

---

## Extensibility

### Adding a new signal

1. Add a function in `signal-computer.js` (e.g., `prefetchBenefitScore`).
2. Add it to the `compute()` return object.
3. It automatically appears in `delta`, gets displayed in the UI, and is available to rules.

### Adding a new rule

```js
InsightEngine.RuleEngine.registerRule(function myRule(signals, features) {
  if (signals.delta.my_signal < -0.1) return [{
    id: 'my_custom_insight',
    type: 'custom',
    direction: 'regressed',
    confidence: 0.6,
    impact: 'medium',
    summary: 'Something regressed',
    evidence: { /* ... */ }
  }];
  return null;
});
```

### Adding a new metric source

Extend `FeatureExtractor.extract()` to read additional fields from `perfSide`.  Then add corresponding signal formulas and rules.

---

## Constraints

| Property | Guarantee |
|----------|-----------|
| Deterministic | Phase 1 is a pure function of (IR + metrics) |
| No hardcoded labels | Rules never reference "tiling", "unrolling", etc. |
| CPU + GPU | Feature extraction and signals branch on `meta.is_gpu` |
| LLM isolation | Phase 2 formats, never overrides |
| ML isolation | Phase 3 predicts separately, never replaces |
| Structured JSON | All intermediate and final outputs are serialisable |

---

## File map

```
web/insight-engine/
├── feature-extractor.js   Module 1  FeatureExtractor
├── signal-computer.js     Module 2  SignalComputer
├── rule-engine.js         Module 3  RuleEngine
├── insight-aggregator.js  Module 4  InsightAggregator
├── llm-explainer.js       Phase 2   LLMExplainer
├── ml-model.js            Phase 3   MLModel (skeleton)
└── engine.js              Orchestrator  InsightEngine.analyze()
```
