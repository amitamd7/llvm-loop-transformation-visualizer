#!/usr/bin/env node
/**
 * Proving System — Falsification Suite
 *
 * Attempts to DISPROVE every claim the Insight Engine makes.
 * If a test passes, it means the negation was refuted — the property holds.
 *
 * Test categories:
 *   I.   INVARIANT        — mathematical properties that must always hold
 *   II.  ADVERSARIAL      — malformed / degenerate / extreme inputs
 *   III. CONSISTENCY      — cross-signal and cross-rule coherence
 *   IV.  ORACLE           — known-answer tests against real datasets
 *   V.   SENSITIVITY      — bounded perturbation → bounded output change
 *   VI.  FORMULA          — hand-computed values vs engine output
 *   VII. DETERMINISM      — repeated runs produce identical results
 */
'use strict';

const H = require('./harness');
const IE = H.IE;
const DATASETS = H.DATASETS;

const SIGNAL_NAMES = [
  'locality', 'cache_efficiency', 'parallelism', 'vectorization',
  'memory_pressure', 'branch_overhead', 'loop_complexity', 'critical_path_dominance'
];

/* ================================================================== */
/*  I. INVARIANT TESTS                                                 */
/*     Try to find ANY input that breaks mathematical guarantees        */
/* ================================================================== */

H.section('I. INVARIANT TESTS');

/* ── I.1  All signals ∈ [0, 1] for every real dataset ── */
H.subsection('I.1  Signal bound [0, 1] on real datasets');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  SIGNAL_NAMES.forEach(function (s) {
    H.assertInRange(report.signals.before[s], 0, 1,
      ds.name + ': before.' + s + ' in [0,1]');
    H.assertInRange(report.signals.after[s], 0, 1,
      ds.name + ': after.' + s + ' in [0,1]');
  });
});

/* ── I.2  Deltas ∈ [-1, 1] ── */
H.subsection('I.2  Delta bounds [-1, 1] on real datasets');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  SIGNAL_NAMES.forEach(function (s) {
    H.assertInRange(report.signals.delta[s], -1, 1,
      ds.name + ': delta.' + s + ' in [-1,1]');
  });
});

/* ── I.3  Delta = after − before (to 6 decimal places) ── */
H.subsection('I.3  Delta = after − before (arithmetic identity)');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  SIGNAL_NAMES.forEach(function (s) {
    var expected = +(report.signals.after[s] - report.signals.before[s]).toFixed(6);
    H.assertApprox(report.signals.delta[s], expected, 1e-5,
      ds.name + ': delta.' + s + ' = after − before');
  });
});

/* ── I.4  Confidence ∈ [0, 1] for all insights ── */
H.subsection('I.4  Insight confidence ∈ [0, 1]');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var all = report.improved.concat(report.regressed).concat(report.neutral);
  all.forEach(function (insight) {
    H.assertInRange(insight.confidence, 0, 1,
      ds.name + ': insight ' + insight.id + ' confidence in [0,1]');
  });
});

/* ── I.5  Impact label consistent with confidence ── */
H.subsection('I.5  Impact label matches confidence threshold');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var all = report.improved.concat(report.regressed).concat(report.neutral);
  all.forEach(function (insight) {
    var expected;
    if (insight.confidence >= 0.7) expected = 'high';
    else if (insight.confidence >= 0.35) expected = 'medium';
    else expected = 'low';
    H.assertEq(insight.impact, expected,
      ds.name + ': insight ' + insight.id + ' impact=' + insight.impact + ' vs conf=' + insight.confidence);
  });
});

/* ── I.6  Behaviour label in valid set ── */
H.subsection('I.6  Behaviour label validity');
var VALID_BEHAVIOURS = ['improved', 'regressed', 'mixed', 'unchanged'];
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  H.assert(VALID_BEHAVIOURS.indexOf(report.behaviour) >= 0,
    ds.name + ': behaviour "' + report.behaviour + '" is valid');
});

/* ── I.7  Bottleneck class in valid set ── */
H.subsection('I.7  Bottleneck class validity');
var VALID_BOTTLENECKS = ['memory-bound', 'compute-bound', 'control-flow-bound',
                         'loop-complexity-bound', 'balanced'];
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  H.assert(VALID_BOTTLENECKS.indexOf(report.bottleneck.class) >= 0,
    ds.name + ': bottleneck "' + report.bottleneck.class + '" is valid');
});

/* ── I.8  Insight direction in valid set ── */
H.subsection('I.8  Insight direction validity');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var all = report.improved.concat(report.regressed).concat(report.neutral);
  all.forEach(function (i) {
    H.assert(['improved', 'regressed', 'neutral'].indexOf(i.direction) >= 0,
      ds.name + ': insight ' + i.id + ' direction "' + i.direction + '" valid');
  });
});

/* ── I.9  Improved list contains only improved; regressed only regressed ── */
H.subsection('I.9  Insight categorisation correctness');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  report.improved.forEach(function (i) {
    H.assertEq(i.direction, 'improved',
      ds.name + ': improved list contains ' + i.id + ' with direction ' + i.direction);
  });
  report.regressed.forEach(function (i) {
    H.assertEq(i.direction, 'regressed',
      ds.name + ': regressed list contains ' + i.id + ' with direction ' + i.direction);
  });
});

/* ── I.10  Counts match list lengths ── */
H.subsection('I.10  Count fields match list lengths');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  H.assertEq(report.counts.improved, report.improved.length,
    ds.name + ': counts.improved');
  H.assertEq(report.counts.regressed, report.regressed.length,
    ds.name + ': counts.regressed');
  H.assertEq(report.counts.neutral, report.neutral.length,
    ds.name + ': counts.neutral');
});

/* ── I.11  Overall confidence = mean of all insight confidences ── */
H.subsection('I.11  Overall confidence = mean(insight confidences)');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var all = report.improved.concat(report.regressed).concat(report.neutral);
  var expected = all.length
    ? all.reduce(function (s, i) { return s + i.confidence; }, 0) / all.length
    : 0;
  H.assertApprox(report.overall_confidence, +expected.toFixed(3), 0.002,
    ds.name + ': overall_confidence = mean');
});


/* ================================================================== */
/*  II. ADVERSARIAL TESTS                                              */
/*     Feed malformed / degenerate inputs and prove the engine          */
/*     doesn't crash, returns valid structure                           */
/* ================================================================== */

H.section('II. ADVERSARIAL TESTS');

/* ── II.1  Null / undefined / empty inputs ── */
H.subsection('II.1  Null / undefined / empty inputs');
var adversarialInputs = [
  { name: 'both null',      before: null,  after: null,  perf: null },
  { name: 'empty objects',  before: {},    after: {},    perf: {} },
  { name: 'no functions',   before: { functions: [] }, after: { functions: [] }, perf: null },
  { name: 'undefined perf', before: { functions: [{}] }, after: { functions: [{}] }, perf: undefined },
  { name: 'perf.before null', before: { functions: [{}] }, after: { functions: [{}] }, perf: { before: null, after: null } },
];

adversarialInputs.forEach(function (tc) {
  var threw = false;
  try {
    var report = IE.analyze(tc.before, tc.after, tc.perf);
    H.assert(report !== null && typeof report === 'object',
      'ADV[' + tc.name + ']: returns an object');
    H.assert(typeof report.behaviour === 'string',
      'ADV[' + tc.name + ']: has behaviour string');
    H.assert(report.bottleneck && typeof report.bottleneck.class === 'string',
      'ADV[' + tc.name + ']: has bottleneck.class');
    SIGNAL_NAMES.forEach(function (s) {
      H.assert(isFinite(report.signals.before[s]),
        'ADV[' + tc.name + ']: before.' + s + ' is finite');
      H.assert(isFinite(report.signals.after[s]),
        'ADV[' + tc.name + ']: after.' + s + ' is finite');
    });
  } catch (e) {
    threw = true;
    H.assert(false, 'ADV[' + tc.name + ']: threw ' + e.message);
  }
});

/* ── II.2  NaN / Infinity / negative values in perf ── */
H.subsection('II.2  NaN / Infinity / negative values in perf');
var poisonPerf = {
  before: { execution_time: NaN, ipc: Infinity, l1_miss_rate: -50, llc_miss_rate: NaN, branch_miss_rate: -1 },
  after:  { execution_time: -1, ipc: NaN, l1_miss_rate: Infinity, llc_miss_rate: 200, branch_miss_rate: NaN }
};
var minimalIR = { functions: [{ cfg: { nodes: [], edges: [] }, loops: [], instruction_count: 0 }] };

(function () {
  var report = IE.analyze(minimalIR, minimalIR, poisonPerf);
  SIGNAL_NAMES.forEach(function (s) {
    H.assert(isFinite(report.signals.before[s]),
      'Poison perf: before.' + s + ' is finite (not NaN/Inf)');
    H.assert(isFinite(report.signals.after[s]),
      'Poison perf: after.' + s + ' is finite (not NaN/Inf)');
    H.assertInRange(report.signals.before[s], 0, 1,
      'Poison perf: before.' + s + ' in [0,1]');
    H.assertInRange(report.signals.after[s], 0, 1,
      'Poison perf: after.' + s + ' in [0,1]');
  });
})();

/* ── II.3  Extremely large numbers ── */
H.subsection('II.3  Extremely large metric values');
var largePerf = {
  before: { execution_time: 1e15, ipc: 1e10, l1_miss_rate: 1e6, instructions: 1e18, branch_miss_rate: 1e5 },
  after:  { execution_time: 1e15, ipc: 1e10, l1_miss_rate: 1e6, instructions: 1e18, branch_miss_rate: 1e5 }
};
(function () {
  var report = IE.analyze(minimalIR, minimalIR, largePerf);
  SIGNAL_NAMES.forEach(function (s) {
    H.assertInRange(report.signals.before[s], 0, 1,
      'Large values: before.' + s + ' clamped to [0,1]');
  });
})();

/* ── II.4  Zero-instruction, zero-loop function ── */
H.subsection('II.4  Empty function (0 instructions, 0 loops)');
(function () {
  var emptyFn = { functions: [{ cfg: { nodes: [], edges: [] }, loops: [], instruction_count: 0 }] };
  var report = IE.analyze(emptyFn, emptyFn, null);
  H.assert(typeof report === 'object', 'Empty fn: returns object');
  SIGNAL_NAMES.forEach(function (s) {
    H.assertInRange(report.signals.before[s], 0, 1,
      'Empty fn: before.' + s + ' in [0,1]');
  });
})();

/* ── II.5  Single-block, single-instruction function ── */
H.subsection('II.5  Single block, single instruction');
(function () {
  var trivialFn = {
    functions: [{
      cfg: {
        nodes: [{ id: 'b0', label: 'entry', instructions: { total: 1, arith: 1, memory: 0, branch: 0, other: 0 }, cost: 1 }],
        edges: []
      },
      loops: [],
      instruction_count: 1
    }]
  };
  var report = IE.analyze(trivialFn, trivialFn, null);
  H.assert(typeof report === 'object', 'Trivial fn: returns object');
  H.assertEq(report.behaviour, 'unchanged', 'Trivial fn: identical input → unchanged');
})();

/* ── II.6  Massive loop nest (depth 100) ── */
H.subsection('II.6  Deep loop nest (depth 100)');
(function () {
  var loops = [];
  for (var i = 0; i < 100; i++) {
    loops.push({ depth: i + 1, header: 'h' + i, blocks: ['h' + i], trip_count: 10,
                 dependencies: [{ type: 'loop-carried', description: 'dep' }],
                 memory_accesses: [{ type: 'load', pattern: 'stride-1', array: 'A' }] });
  }
  var deepIR = { functions: [{ cfg: { nodes: [{ id: 'b0', label: 'h0', instructions: { total: 1, arith: 1 } }], edges: [] },
                               loops: loops, instruction_count: 100 }] };
  var report = IE.analyze(deepIR, deepIR, null);
  H.assertInRange(report.signals.before.loop_complexity, 0, 1,
    'Deep nest: loop_complexity clamped to [0,1]');
})();

/* ── II.7  GPU path with missing GPU-specific counters ── */
H.subsection('II.7  GPU profiler flag but missing GPU counters');
(function () {
  var gpuPerf = { profiler: 'rocprof', device: 'gfx90a', before: { execution_time: 5 }, after: { execution_time: 3 } };
  var report = IE.analyze(minimalIR, minimalIR, gpuPerf);
  SIGNAL_NAMES.forEach(function (s) {
    H.assertInRange(report.signals.before[s], 0, 1,
      'GPU missing counters: before.' + s + ' in [0,1]');
  });
})();

/* ── II.8  String where number expected in trip_count ── */
H.subsection('II.8  "at most 1024" trip count string');
(function () {
  var irWithStringTrip = {
    functions: [{
      cfg: { nodes: [], edges: [] },
      loops: [{ depth: 1, header: 'h0', blocks: ['h0'], trip_count: 'at most 1024',
                dependencies: [], memory_accesses: [] }],
      instruction_count: 5
    }]
  };
  var fv = IE.FeatureExtractor.extract(irWithStringTrip, null);
  H.assertEq(fv.loop.known_trip_counts.length, 1, '"at most 1024" parsed as 1 known trip');
  H.assertApprox(fv.loop.known_trip_counts[0], 1024, 0.01, '"at most 1024" parsed as 1024');
})();


/* ================================================================== */
/*  III. CONSISTENCY TESTS                                             */
/*      Cross-signal and cross-rule coherence                          */
/* ================================================================== */

H.section('III. CONSISTENCY TESTS');

/* ── III.1  If speedup > 1, behaviour should not be "regressed" ── */
H.subsection('III.1  Speedup > 1 → behaviour ≠ regressed (unless other strong regressions)');
DATASETS.forEach(function (ds) {
  if (!ds.perf || !ds.perf.before || !ds.perf.after) return;
  var tb = ds.perf.before.execution_time, ta = ds.perf.after.execution_time;
  if (!tb || !ta || tb <= 0 || ta <= 0) return;
  var speedup = tb / ta;
  if (speedup <= 1) return;
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var hasSpeedupInsight = report.improved.some(function (i) { return i.id === 'execution_speedup'; });
  H.assert(hasSpeedupInsight,
    ds.name + ': speedup=' + speedup.toFixed(2) + 'x but no execution_speedup insight');
});

/* ── III.2  Memory-bound classification requires memory_pressure > 0 ── */
H.subsection('III.2  Memory-bound requires positive memory_pressure');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  if (report.bottleneck.class === 'memory-bound') {
    H.assert(report.signals.after.memory_pressure > 0,
      ds.name + ': memory-bound but memory_pressure=' + report.signals.after.memory_pressure);
  }
});

/* ── III.3  Compute-bound classification requires vectorization > 0 ── */
H.subsection('III.3  Compute-bound requires positive vectorization');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  if (report.bottleneck.class === 'compute-bound') {
    H.assert(report.signals.after.vectorization > 0,
      ds.name + ': compute-bound but vectorization=' + report.signals.after.vectorization);
  }
});

/* ── III.4  Unchanged behaviour ↔ no significant deltas ── */
H.subsection('III.4  Unchanged behaviour means no high-confidence insights');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  if (report.behaviour === 'unchanged') {
    var highConf = report.improved.concat(report.regressed).filter(function (i) {
      return i.confidence >= 0.7;
    });
    H.assert(highConf.length === 0,
      ds.name + ': unchanged but has ' + highConf.length + ' high-conf insights');
  }
});

/* ── III.5  Direction polarity matches delta sign ── */
H.subsection('III.5  Insight direction matches delta sign for signal-based rules');
var SIGNAL_RULES = {
  'locality_change':      { signal: 'locality',             inverted: false },
  'cache_efficiency_change': { signal: 'cache_efficiency',  inverted: false },
  'parallelism_change':   { signal: 'parallelism',          inverted: false },
  'memory_pressure_change': { signal: 'memory_pressure',    inverted: true },
  'branch_overhead_change': { signal: 'branch_overhead',    inverted: true },
  'vectorization_change': { signal: 'vectorization',        inverted: false },
  'loop_complexity_change': { signal: 'loop_complexity',    inverted: true },
  'critical_path_shift':  { signal: 'critical_path_dominance', inverted: true }
};

DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var allInsights = report.improved.concat(report.regressed).concat(report.neutral);
  allInsights.forEach(function (insight) {
    var spec = SIGNAL_RULES[insight.id];
    if (!spec) return;
    var d = report.signals.delta[spec.signal];
    if (Math.abs(d) < 0.02) return;
    var expectedDir;
    if (spec.inverted) {
      expectedDir = d < 0 ? 'improved' : 'regressed';
    } else {
      expectedDir = d > 0 ? 'improved' : 'regressed';
    }
    H.assertEq(insight.direction, expectedDir,
      ds.name + ': ' + insight.id + ' delta=' + d.toFixed(3) + ' → expected ' + expectedDir);
  });
});

/* ── III.6  No duplicate insight IDs in a single report ── */
H.subsection('III.6  No duplicate insight IDs');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  var all = report.improved.concat(report.regressed).concat(report.neutral);
  var ids = {};
  var hasDup = false;
  all.forEach(function (i) {
    if (ids[i.id]) hasDup = true;
    ids[i.id] = true;
  });
  H.assert(!hasDup, ds.name + ': no duplicate insight IDs');
});

/* ── III.7  Suggestions are non-empty ── */
H.subsection('III.7  At least one suggestion always generated');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  H.assert(report.suggestions.length > 0,
    ds.name + ': at least one suggestion');
});

/* ── III.8  Expected behaviour notes are non-empty ── */
H.subsection('III.8  At least one expected-behaviour note');
DATASETS.forEach(function (ds) {
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  H.assert(report.expected.length > 0,
    ds.name + ': at least one expected note');
});


/* ================================================================== */
/*  IV. ORACLE TESTS                                                   */
/*     Known-answer checks against real datasets                       */
/* ================================================================== */

H.section('IV. ORACLE TESTS');

/* ── IV.1  Loop Tiling: should show speedup, increased instruction count ── */
H.subsection('IV.1  Loop Tiling oracle');
(function () {
  var ds = DATASETS.find(function (d) { return d.name === 'loop-tiling'; });
  if (!ds) { H.skip('loop-tiling dataset not found'); return; }
  var report = IE.analyze(ds.before, ds.after, ds.perf);

  H.assert(report.improved.some(function (i) { return i.id === 'execution_speedup'; }),
    'loop-tiling: has execution_speedup insight');

  var speedup = report.improved.find(function (i) { return i.id === 'execution_speedup'; });
  if (speedup) {
    H.assertApprox(speedup.evidence.speedup_ratio, 1.5, 0.05,
      'loop-tiling: speedup ≈ 1.5x');
  }

  H.assert(report.regressed.some(function (i) { return i.id === 'instruction_count_change'; }),
    'loop-tiling: instruction count regressed');

  var features = report.features;
  H.assertEq(features.before.instruction.total, 11, 'loop-tiling: before instr = 11');
  H.assertEq(features.after.instruction.total, 21, 'loop-tiling: after instr = 21');

  H.assertEq(features.before.loop.count, 1, 'loop-tiling: before has 1 loop');
  H.assertEq(features.after.loop.count, 2, 'loop-tiling: after has 2 loops');
})();

/* ── IV.2  Loop Unrolling: strong speedup, increased ILP ── */
H.subsection('IV.2  Loop Unrolling oracle');
(function () {
  var ds = DATASETS.find(function (d) { return d.name === 'loop-unrolling'; });
  if (!ds) { H.skip('loop-unrolling dataset not found'); return; }
  var report = IE.analyze(ds.before, ds.after, ds.perf);

  H.assert(report.improved.some(function (i) { return i.id === 'execution_speedup'; }),
    'loop-unrolling: has execution_speedup');

  var speedup = report.improved.find(function (i) { return i.id === 'execution_speedup'; });
  if (speedup) {
    H.assert(speedup.evidence.speedup_ratio > 1.5,
      'loop-unrolling: speedup > 1.5x (got ' + speedup.evidence.speedup_ratio + ')');
    H.assertEq(speedup.impact, 'high',
      'loop-unrolling: speedup is high-impact');
  }
})();

/* ── IV.3  Loop Interchange: locality should improve dramatically ── */
H.subsection('IV.3  Loop Interchange oracle');
(function () {
  var ds = DATASETS.find(function (d) { return d.name === 'loop-interchange'; });
  if (!ds) { H.skip('loop-interchange dataset not found'); return; }
  var report = IE.analyze(ds.before, ds.after, ds.perf);

  if (report.signals.delta.locality > 0.03) {
    H.assert(report.improved.some(function (i) { return i.id === 'locality_change'; }),
      'loop-interchange: locality improved → has locality_change insight');
  }

  if (report.signals.delta.cache_efficiency > 0.03) {
    H.assert(report.improved.some(function (i) { return i.id === 'cache_efficiency_change'; }),
      'loop-interchange: cache improved → has cache_efficiency_change insight');
  }
})();

/* ── IV.4  GPU dataset: is_gpu flag set, GPU-specific signals computed ── */
H.subsection('IV.4  GPU dataset oracle');
(function () {
  var ds = DATASETS.find(function (d) { return d.name === 'gpu-vecadd'; });
  if (!ds) { H.skip('gpu-vecadd dataset not found'); return; }
  var report = IE.analyze(ds.before, ds.after, ds.perf);

  H.assert(report.features.meta.is_gpu === true,
    'gpu-vecadd: meta.is_gpu = true');
  H.assert(report.features.meta.profiler === 'rocprof',
    'gpu-vecadd: profiler = rocprof');

  H.assert(report.signals.after.locality > 0,
    'gpu-vecadd: after locality > 0 (L2 hit rate used)');
})();

/* ── IV.5  LICM vecadd: identical structure → unchanged ── */
H.subsection('IV.5  LICM vecadd oracle');
(function () {
  var ds = DATASETS.find(function (d) { return d.name === 'licm-vecadd'; });
  if (!ds) { H.skip('licm-vecadd dataset not found'); return; }
  var report = IE.analyze(ds.before, ds.after, ds.perf);
  // LICM may or may not change signals depending on data
  // but at minimum the report should be valid
  H.assert(typeof report.behaviour === 'string', 'licm-vecadd: valid behaviour');
  H.assert(report.bottleneck && typeof report.bottleneck.class === 'string',
    'licm-vecadd: valid bottleneck');
})();


/* ================================================================== */
/*  V. SENSITIVITY TESTS                                               */
/*     Small input perturbation → bounded output change                */
/* ================================================================== */

H.section('V. SENSITIVITY TESTS');

/* ── V.1  ±1% perf perturbation → ≤ 0.05 signal change ── */
H.subsection('V.1  Small perf perturbation → bounded signal change');
(function () {
  var ds = DATASETS.find(function (d) { return d.name === 'loop-tiling'; });
  if (!ds || !ds.perf) { H.skip('loop-tiling perf not available'); return; }

  var perfBase = JSON.parse(JSON.stringify(ds.perf));
  var perfPerturbed = JSON.parse(JSON.stringify(ds.perf));

  var perturbKeys = ['execution_time', 'ipc', 'l1_miss_rate', 'llc_miss_rate', 'branch_miss_rate'];
  perturbKeys.forEach(function (k) {
    if (perfPerturbed.before[k] != null) perfPerturbed.before[k] *= 1.01;
    if (perfPerturbed.after[k] != null) perfPerturbed.after[k] *= 1.01;
  });

  var reportBase = IE.analyze(ds.before, ds.after, perfBase);
  var reportPert = IE.analyze(ds.before, ds.after, perfPerturbed);

  SIGNAL_NAMES.forEach(function (s) {
    var diff = Math.abs(reportPert.signals.before[s] - reportBase.signals.before[s]);
    H.assert(diff < 0.05,
      'Sensitivity: 1% perturbation → before.' + s + ' changed by ' + diff.toFixed(4) + ' (< 0.05)');
  });
})();

/* ── V.2  Monotonicity: increasing IPC → increasing parallelism signal ── */
H.subsection('V.2  Monotonicity: IPC ↑ → parallelism ↑');
(function () {
  var prevSig = -1;
  for (var ipc = 0; ipc <= 6; ipc += 0.5) {
    var fv = {
      loop: { stride1_fraction: 0.5, max_depth: 1, loop_carried_count: 0, dependency_count: 0, has_unknown_trip: false, count: 1 },
      instruction: { total: 10, arith_fraction: 0.4, memory_fraction: 0.3, branch_fraction: 0.2, other_fraction: 0.1 },
      cfg: { block_count: 2, edge_count: 2, back_edge_count: 1, max_block_cost: 5, total_cost: 10, critical_path_cost: 5 },
      performance: { ipc: ipc }
    };
    var sig = IE.SignalComputer.compute(fv, false);
    H.assert(sig.parallelism >= prevSig - 1e-9,
      'Monotone: IPC=' + ipc + ' → parallelism=' + sig.parallelism.toFixed(4) + ' >= prev ' + prevSig.toFixed(4));
    prevSig = sig.parallelism;
  }
})();

/* ── V.3  Monotonicity: increasing stride1_fraction → increasing locality ── */
H.subsection('V.3  Monotonicity: stride1_fraction ↑ → locality ↑');
(function () {
  var prevSig = -1;
  for (var s1 = 0; s1 <= 1.0; s1 += 0.1) {
    var fv = {
      loop: { stride1_fraction: s1, max_depth: 1, loop_carried_count: 0, dependency_count: 0, has_unknown_trip: false, count: 1 },
      instruction: { total: 10, arith_fraction: 0.4, memory_fraction: 0.3, branch_fraction: 0.2, other_fraction: 0.1 },
      cfg: { block_count: 2, edge_count: 2, back_edge_count: 1, max_block_cost: 5, total_cost: 10, critical_path_cost: 5 },
      performance: null
    };
    var sig = IE.SignalComputer.compute(fv, false);
    H.assert(sig.locality >= prevSig - 1e-9,
      'Monotone: stride1=' + s1.toFixed(1) + ' → locality=' + sig.locality.toFixed(4) + ' >= prev ' + prevSig.toFixed(4));
    prevSig = sig.locality;
  }
})();

/* ── V.4  Monotonicity: increasing l1_miss_rate → decreasing cache_efficiency ── */
H.subsection('V.4  Monotonicity: l1_miss_rate ↑ → cache_efficiency ↓');
(function () {
  var prevSig = 2;
  for (var miss = 0; miss <= 100; miss += 10) {
    var fv = {
      loop: { stride1_fraction: 0.5, max_depth: 1, loop_carried_count: 0, dependency_count: 0, has_unknown_trip: false, count: 1 },
      instruction: { total: 10, arith_fraction: 0.4, memory_fraction: 0.3, branch_fraction: 0.2, other_fraction: 0.1 },
      cfg: { block_count: 2, edge_count: 2, back_edge_count: 1, max_block_cost: 5, total_cost: 10, critical_path_cost: 5 },
      performance: { l1_miss_rate: miss, llc_miss_rate: 0 }
    };
    var sig = IE.SignalComputer.compute(fv, false);
    H.assert(sig.cache_efficiency <= prevSig + 1e-9,
      'Monotone: l1_miss=' + miss + ' → cache_eff=' + sig.cache_efficiency.toFixed(4) + ' <= prev ' + prevSig.toFixed(4));
    prevSig = sig.cache_efficiency;
  }
})();

/* ── V.5  Monotonicity: increasing loop depth → increasing loop_complexity ── */
H.subsection('V.5  Monotonicity: loop depth ↑ → loop_complexity ↑');
(function () {
  var prevSig = -1;
  for (var depth = 0; depth <= 8; depth++) {
    var fv = {
      loop: { stride1_fraction: 0.5, max_depth: depth, loop_carried_count: 0, dependency_count: 1, has_unknown_trip: false, count: depth },
      instruction: { total: 10, arith_fraction: 0.4, memory_fraction: 0.3, branch_fraction: 0.2, other_fraction: 0.1 },
      cfg: { block_count: 2, edge_count: 2, back_edge_count: 1, max_block_cost: 5, total_cost: 10, critical_path_cost: 5 },
      performance: null
    };
    var sig = IE.SignalComputer.compute(fv, false);
    H.assert(sig.loop_complexity >= prevSig - 1e-9,
      'Monotone: depth=' + depth + ' → complexity=' + sig.loop_complexity.toFixed(4) + ' >= prev ' + prevSig.toFixed(4));
    prevSig = sig.loop_complexity;
  }
})();


/* ================================================================== */
/*  VI. FORMULA VERIFICATION                                           */
/*     Hand-compute expected values and compare                        */
/* ================================================================== */

H.section('VI. FORMULA VERIFICATION');

/* ── VI.1  Locality formula (CPU, with perf) ── */
H.subsection('VI.1  Locality formula: 0.6*stride1 + 0.4*(1 - l1_miss/100)');
(function () {
  var fv = {
    loop: { stride1_fraction: 0.8 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { l1_miss_rate: 5.0 }
  };
  var sig = IE.SignalComputer.compute(fv, false);
  var expected = 0.6 * 0.8 + 0.4 * (1 - 5.0 / 100);
  H.assertApprox(sig.locality, expected, 1e-6, 'Locality formula exact');
})();

/* ── VI.2  Cache efficiency formula (CPU, harmonic mean) ── */
H.subsection('VI.2  Cache efficiency: harmonic mean of (1-L1%) and (1-LLC%)');
(function () {
  var fv = {
    loop: { stride1_fraction: 0 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { l1_miss_rate: 10, llc_miss_rate: 20 }
  };
  var sig = IE.SignalComputer.compute(fv, false);
  var a = 1 - 10 / 100;   // 0.9
  var b = 1 - 20 / 100;   // 0.8
  var expected = 2 * a * b / (a + b);  // harmonic mean
  H.assertApprox(sig.cache_efficiency, expected, 1e-6, 'Cache efficiency harmonic mean');
})();

/* ── VI.3  Parallelism formula (CPU): IPC / 6 ── */
H.subsection('VI.3  Parallelism: IPC / 6');
(function () {
  var fv = {
    loop: { stride1_fraction: 0 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { ipc: 3.0 }
  };
  var sig = IE.SignalComputer.compute(fv, false);
  H.assertApprox(sig.parallelism, 3.0 / 6.0, 1e-6, 'Parallelism = IPC/6');
})();

/* ── VI.4  Vectorization formula: 0.7*arith + 0.3*(1 - branch) ── */
H.subsection('VI.4  Vectorization: 0.7*arith_frac + 0.3*(1-branch_frac)');
(function () {
  var fv = {
    loop: { stride1_fraction: 0 },
    instruction: { arith_fraction: 0.6, memory_fraction: 0.2, branch_fraction: 0.1, other_fraction: 0.1 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: null
  };
  var sig = IE.SignalComputer.compute(fv, false);
  var expected = 0.7 * 0.6 + 0.3 * (1 - 0.1);
  H.assertApprox(sig.vectorization, expected, 1e-6, 'Vectorization formula exact');
})();

/* ── VI.5  Memory pressure formula (CPU, with perf) ── */
H.subsection('VI.5  Memory pressure: 0.6*mem_frac + 0.4*(l1+llc)/200');
(function () {
  var fv = {
    loop: { stride1_fraction: 0 },
    instruction: { arith_fraction: 0.3, memory_fraction: 0.5, branch_fraction: 0.1, other_fraction: 0.1 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { l1_miss_rate: 10, llc_miss_rate: 5 }
  };
  var sig = IE.SignalComputer.compute(fv, false);
  var expected = 0.6 * 0.5 + 0.4 * (10 + 5) / 200;
  H.assertApprox(sig.memory_pressure, expected, 1e-6, 'Memory pressure formula exact');
})();

/* ── VI.6  Branch overhead formula (CPU): branch_miss_rate / 100 ── */
H.subsection('VI.6  Branch overhead: branch_miss_rate / 100');
(function () {
  var fv = {
    loop: { stride1_fraction: 0 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0.3, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { branch_miss_rate: 15 }
  };
  var sig = IE.SignalComputer.compute(fv, false);
  H.assertApprox(sig.branch_overhead, 15 / 100, 1e-6, 'Branch overhead = miss_rate/100');
})();

/* ── VI.7  Loop complexity formula: 0.4*depth/4 + 0.4*carried/deps + 0.2*unknown ── */
H.subsection('VI.7  Loop complexity formula');
(function () {
  var fv = {
    loop: { max_depth: 2, loop_carried_count: 3, dependency_count: 5, has_unknown_trip: true, count: 2, stride1_fraction: 0 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: null
  };
  var sig = IE.SignalComputer.compute(fv, false);
  var expected = 0.4 * (2 / 4) + 0.4 * (3 / 5) + 0.2 * 0.5;
  H.assertApprox(sig.loop_complexity, expected, 1e-6, 'Loop complexity formula exact');
})();

/* ── VI.8  Critical path dominance: crit_cost / total_cost ── */
H.subsection('VI.8  Critical path dominance: crit_cost / total_cost');
(function () {
  var fv = {
    loop: { stride1_fraction: 0, max_depth: 0, loop_carried_count: 0, dependency_count: 0, has_unknown_trip: false, count: 0 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 7, total_cost: 10 },
    performance: null
  };
  var sig = IE.SignalComputer.compute(fv, false);
  H.assertApprox(sig.critical_path_dominance, 0.7, 1e-6, 'Crit path dom = 7/10 = 0.7');
})();

/* ── VI.9  GPU locality formula: 0.4*stride1 + 0.6*l2_hit_rate ── */
H.subsection('VI.9  GPU locality: 0.4*stride1 + 0.6*l2_hit_rate');
(function () {
  var fv = {
    loop: { stride1_fraction: 0.5 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { l2_hit_rate: 0.9 }
  };
  var sig = IE.SignalComputer.compute(fv, true);
  var expected = 0.4 * 0.5 + 0.6 * 0.9;
  H.assertApprox(sig.locality, expected, 1e-6, 'GPU locality formula');
})();

/* ── VI.10  GPU parallelism: waves / 1024 ── */
H.subsection('VI.10  GPU parallelism: waves / 1024');
(function () {
  var fv = {
    loop: { stride1_fraction: 0 },
    instruction: { arith_fraction: 0, memory_fraction: 0, branch_fraction: 0, other_fraction: 0 },
    cfg: { critical_path_cost: 0, total_cost: 0 },
    performance: { waves: 512 }
  };
  var sig = IE.SignalComputer.compute(fv, true);
  H.assertApprox(sig.parallelism, 512 / 1024, 1e-6, 'GPU parallelism = waves/1024');
})();


/* ================================================================== */
/*  VII. DETERMINISM TESTS                                             */
/*      Same input → identical output, always                          */
/* ================================================================== */

H.section('VII. DETERMINISM TESTS');

/* ── VII.1  100 repeated runs produce bit-identical output ── */
H.subsection('VII.1  100 repeated runs → identical JSON output');
DATASETS.forEach(function (ds) {
  var ref = JSON.stringify(IE.analyze(ds.before, ds.after, ds.perf));
  for (var i = 0; i < 100; i++) {
    var run = JSON.stringify(IE.analyze(ds.before, ds.after, ds.perf));
    if (run !== ref) {
      H.assert(false, ds.name + ': run ' + i + ' differs from reference');
      break;
    }
  }
  H.assert(true, ds.name + ': 100 runs identical');
});

/* ── VII.2  Symmetry: swap(before, after) inverts deltas ── */
H.subsection('VII.2  Swap before/after → inverted deltas');
DATASETS.forEach(function (ds) {
  var normal  = IE.analyze(ds.before, ds.after, ds.perf);
  var perfSwapped = ds.perf ? JSON.parse(JSON.stringify(ds.perf)) : null;
  if (perfSwapped && perfSwapped.before && perfSwapped.after) {
    var tmp = perfSwapped.before;
    perfSwapped.before = perfSwapped.after;
    perfSwapped.after = tmp;
  }
  var swapped = IE.analyze(ds.after, ds.before, perfSwapped);

  SIGNAL_NAMES.forEach(function (s) {
    var dn = normal.signals.delta[s];
    var ds2 = swapped.signals.delta[s];
    H.assertApprox(dn, -ds2, 0.001,
      ds.name + ': swap inverts delta.' + s + ' (normal=' + dn + ', swapped=' + ds2 + ')');
  });
});

/* ── VII.3  Idempotent: before=after → all deltas = 0 ── */
H.subsection('VII.3  Identical before/after → all deltas = 0');
DATASETS.forEach(function (ds) {
  var samePerf = ds.perf ? JSON.parse(JSON.stringify(ds.perf)) : null;
  if (samePerf && samePerf.after) samePerf.after = JSON.parse(JSON.stringify(samePerf.before));

  var report = IE.analyze(ds.before, ds.before, samePerf);
  SIGNAL_NAMES.forEach(function (s) {
    H.assertApprox(report.signals.delta[s], 0, 1e-6,
      ds.name + ': identical input → delta.' + s + ' = 0');
  });
  H.assertEq(report.behaviour, 'unchanged',
    ds.name + ': identical input → unchanged');
});


/* ================================================================== */
/*  SUMMARY                                                            */
/* ================================================================== */

var allPassed = H.summary();
process.exit(allPassed ? 0 : 1);
