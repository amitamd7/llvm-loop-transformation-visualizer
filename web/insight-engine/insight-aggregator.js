/**
 * InsightAggregator — Phase 1, Module 4
 *
 * Pure function: (Insight[], SignalVector pair) → AggregatedReport
 *
 * Aggregates rule outputs into:
 *   1. Bottleneck classification (memory-bound, compute-bound, …)
 *   2. Behaviour summary (improved / regressed / mixed)
 *   3. Ranked insight list (improved vs regressed)
 *   4. Overall confidence
 *
 * @module InsightEngine.InsightAggregator
 */
(function (ns) {
  'use strict';

  /* ------------------------------------------------------------------ */
  /*  Bottleneck classifier                                              */
  /*                                                                     */
  /*  Uses the AFTER signal vector to decide the dominant bottleneck.    */
  /*  This is a simple argmax over weighted anti-signals.                */
  /* ------------------------------------------------------------------ */

  var BOTTLENECK_SIGNALS = [
    { key: 'memory_pressure', label: 'memory-bound', weight: 1.0 },
    { key: 'branch_overhead', label: 'control-flow-bound', weight: 0.8 },
    { key: 'loop_complexity', label: 'loop-complexity-bound', weight: 0.6 }
  ];

  function classifyBottleneck(afterSignals) {
    var best = null, bestScore = -1;
    BOTTLENECK_SIGNALS.forEach(function (b) {
      var s = (afterSignals[b.key] || 0) * b.weight;
      if (s > bestScore) { bestScore = s; best = b.label; }
    });

    var computeScore = (afterSignals.vectorization || 0) *
      (1 - (afterSignals.memory_pressure || 0));
    if (computeScore > bestScore) {
      best = 'compute-bound';
      bestScore = computeScore;
    }

    if (bestScore < 0.15) best = 'balanced';

    return { class: best, score: +bestScore.toFixed(3) };
  }

  /* ------------------------------------------------------------------ */
  /*  Overall behaviour                                                  */
  /* ------------------------------------------------------------------ */

  function classifyBehaviour(insights) {
    var imp = 0, reg = 0;
    insights.forEach(function (i) {
      if (i.direction === 'improved') imp += i.confidence;
      if (i.direction === 'regressed') reg += i.confidence;
    });
    if (imp > reg * 1.5) return 'improved';
    if (reg > imp * 1.5) return 'regressed';
    if (imp + reg < 0.1) return 'unchanged';
    return 'mixed';
  }

  /* ------------------------------------------------------------------ */
  /*  Expected behaviour from BEFORE signals (pre-transformation)        */
  /* ------------------------------------------------------------------ */

  function expectedBehaviour(beforeSignals) {
    var notes = [];
    if (beforeSignals.memory_pressure > 0.6)
      notes.push('high memory pressure may limit gains from compute-focused transforms');
    if (beforeSignals.locality < 0.3)
      notes.push('poor baseline locality — tiling or interchange could help');
    if (beforeSignals.branch_overhead > 0.4)
      notes.push('significant branch overhead — unrolling may reduce mispredictions');
    if (beforeSignals.loop_complexity > 0.7)
      notes.push('complex loop nest — transformations may increase register pressure');
    if (beforeSignals.parallelism < 0.2)
      notes.push('low ILP / occupancy — investigate serialisation bottleneck');
    if (!notes.length) notes.push('no dominant bottleneck detected in baseline');
    return notes;
  }

  /* ------------------------------------------------------------------ */
  /*  Suggestions (deterministic, signal-driven)                         */
  /* ------------------------------------------------------------------ */

  function generateSuggestions(beforeSig, afterSig, delta) {
    var out = [];
    if (delta.locality < -0.05)
      out.push('Locality regressed — consider a tiling or prefetch strategy.');
    if (delta.memory_pressure > 0.1 && delta.cache_efficiency < -0.05)
      out.push('Memory pressure increased with worse cache efficiency — check working-set size vs cache capacity.');
    if (delta.branch_overhead > 0.05)
      out.push('Branch overhead grew — partial unrolling might amortise branch costs.');
    if (afterSig.parallelism < 0.25 && beforeSig.parallelism < 0.25)
      out.push('Parallelism remains low in both versions — investigate loop-carried dependencies or serialising memory accesses.');
    if (delta.vectorization < -0.1)
      out.push('Compute density dropped — the transformation may have introduced non-arithmetic overhead (index calculations, bounds checks).');
    if (afterSig.critical_path_dominance > 0.7)
      out.push('Critical path dominates the loop — optimising the hottest block will have outsized impact.');
    if (!out.length)
      out.push('Signals are stable — profile at finer granularity (per-block cost) for deeper insight.');
    return out;
  }

  /* ------------------------------------------------------------------ */
  /*  Public API                                                         */
  /* ------------------------------------------------------------------ */

  /**
   * Aggregate insights into a structured report.
   *
   * @param {Insight[]} insights   - from RuleEngine.evaluate()
   * @param {{ before, after, delta }} signals - from SignalComputer.computePair()
   * @returns {AggregatedReport}
   */
  function aggregate(insights, signals) {
    var improved = insights.filter(function (i) { return i.direction === 'improved'; });
    var regressed = insights.filter(function (i) { return i.direction === 'regressed'; });
    var neutral = insights.filter(function (i) { return i.direction === 'neutral'; });

    var meanConf = insights.length
      ? insights.reduce(function (s, i) { return s + i.confidence; }, 0) / insights.length
      : 0;

    return {
      behaviour: classifyBehaviour(insights),
      bottleneck: classifyBottleneck(signals.after),
      expected: expectedBehaviour(signals.before),
      suggestions: generateSuggestions(signals.before, signals.after, signals.delta),
      overall_confidence: +meanConf.toFixed(3),
      counts: {
        improved: improved.length,
        regressed: regressed.length,
        neutral: neutral.length
      },
      improved: improved,
      regressed: regressed,
      neutral: neutral,
      signals: signals
    };
  }

  ns.InsightAggregator = { aggregate: aggregate, classifyBottleneck: classifyBottleneck };

})(window.InsightEngine = window.InsightEngine || {});
