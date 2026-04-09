/**
 * RuleEngine — Phase 1, Module 3
 *
 * A registry of composable, stateless rules.  Each rule is a pure function:
 *
 *   (signals, features, meta) → Insight[] | null
 *
 * where
 *   signals = { before, after, delta }   (from SignalComputer.computePair)
 *   features = { before, after, meta }   (from FeatureExtractor.extractPair)
 *
 * Rules never reference transformation names.  They describe WHAT changed
 * and HOW MUCH, not WHICH optimisation was applied.
 *
 * Insight schema:
 *   {
 *     id:         string,        // machine-readable identifier
 *     type:       string,        // category (locality, parallelism, …)
 *     direction:  "improved" | "regressed" | "neutral",
 *     confidence: 0–1,
 *     impact:     "low" | "medium" | "high",
 *     summary:    string,        // one-line human-readable
 *     evidence:   { … }          // signal values, metric values backing it
 *   }
 *
 * @module InsightEngine.RuleEngine
 */
(function (ns) {
  'use strict';

  var rules = [];

  function impact(conf) {
    return conf >= 0.7 ? 'high' : conf >= 0.35 ? 'medium' : 'low';
  }
  function dir(delta) {
    return delta > 0.02 ? 'improved' : delta < -0.02 ? 'regressed' : 'neutral';
  }
  function pct(a, b) {
    return b !== 0 ? ((b - a) / Math.abs(a)) * 100 : 0;
  }

  /* ================================================================== */
  /*  Rule: Locality change                                              */
  /* ================================================================== */
  rules.push(function localityChange(sig, feat) {
    var d = sig.delta.locality;
    if (Math.abs(d) < 0.03) return null;
    var conf = Math.min(1, Math.abs(d) * 3);
    var pb = (feat.before.performance || {}), pa = (feat.after.performance || {});
    return [{
      id: 'locality_change',
      type: 'locality',
      direction: dir(d),
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Spatial locality ' + (d > 0 ? 'improved' : 'degraded') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        before_locality: +sig.before.locality.toFixed(3),
        after_locality: +sig.after.locality.toFixed(3),
        delta: +d.toFixed(3),
        l1_miss_before: pb.l1_miss_rate,
        l1_miss_after: pa.l1_miss_rate,
        stride1_before: feat.before.loop.stride1_fraction,
        stride1_after: feat.after.loop.stride1_fraction
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Cache efficiency change                                      */
  /* ================================================================== */
  rules.push(function cacheChange(sig, feat) {
    var d = sig.delta.cache_efficiency;
    if (Math.abs(d) < 0.03) return null;
    var conf = Math.min(1, Math.abs(d) * 2.5);
    var pb = feat.before.performance || {}, pa = feat.after.performance || {};
    return [{
      id: 'cache_efficiency_change',
      type: 'cache',
      direction: dir(d),
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Cache efficiency ' + (d > 0 ? 'improved' : 'degraded') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        before: +sig.before.cache_efficiency.toFixed(3),
        after: +sig.after.cache_efficiency.toFixed(3),
        l1_miss_pct_change: pa.l1_miss_rate != null ? pct(pb.l1_miss_rate, pa.l1_miss_rate).toFixed(1) + '%' : null,
        llc_miss_pct_change: pa.llc_miss_rate != null ? pct(pb.llc_miss_rate, pa.llc_miss_rate).toFixed(1) + '%' : null
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Parallelism / occupancy change                               */
  /* ================================================================== */
  rules.push(function parallelismChange(sig, feat) {
    var d = sig.delta.parallelism;
    if (Math.abs(d) < 0.02) return null;
    var conf = Math.min(1, Math.abs(d) * 3);
    var pb = feat.before.performance || {}, pa = feat.after.performance || {};
    var isGpu = feat.meta.is_gpu;
    var label = isGpu ? 'GPU occupancy' : 'Instruction-level parallelism';
    var ev = { before: +sig.before.parallelism.toFixed(3), after: +sig.after.parallelism.toFixed(3) };
    if (isGpu) { ev.waves_before = pb.waves; ev.waves_after = pa.waves; }
    else { ev.ipc_before = pb.ipc; ev.ipc_after = pa.ipc; }
    return [{
      id: 'parallelism_change',
      type: 'parallelism',
      direction: dir(d),
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: label + ' ' + (d > 0 ? 'increased' : 'decreased') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: ev
    }];
  });

  /* ================================================================== */
  /*  Rule: Memory pressure change                                       */
  /* ================================================================== */
  rules.push(function memPressureChange(sig, feat) {
    var d = sig.delta.memory_pressure;
    if (Math.abs(d) < 0.03) return null;
    var conf = Math.min(1, Math.abs(d) * 2.5);
    return [{
      id: 'memory_pressure_change',
      type: 'memory',
      direction: d < 0 ? 'improved' : 'regressed',
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Memory pressure ' + (d < 0 ? 'reduced' : 'increased') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        before: +sig.before.memory_pressure.toFixed(3),
        after: +sig.after.memory_pressure.toFixed(3),
        mem_fraction_before: feat.before.instruction.memory_fraction,
        mem_fraction_after: feat.after.instruction.memory_fraction
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Branch overhead change                                       */
  /* ================================================================== */
  rules.push(function branchChange(sig, feat) {
    var d = sig.delta.branch_overhead;
    if (Math.abs(d) < 0.02) return null;
    var conf = Math.min(1, Math.abs(d) * 4);
    var pb = feat.before.performance || {}, pa = feat.after.performance || {};
    return [{
      id: 'branch_overhead_change',
      type: 'branch',
      direction: d < 0 ? 'improved' : 'regressed',
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Branch overhead ' + (d < 0 ? 'reduced' : 'increased') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        miss_rate_before: pb.branch_miss_rate,
        miss_rate_after: pa.branch_miss_rate,
        branch_fraction_before: feat.before.instruction.branch_fraction,
        branch_fraction_after: feat.after.instruction.branch_fraction
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Vectorization potential change                               */
  /* ================================================================== */
  rules.push(function vecChange(sig, feat) {
    var d = sig.delta.vectorization;
    if (Math.abs(d) < 0.03) return null;
    var conf = Math.min(1, Math.abs(d) * 3);
    return [{
      id: 'vectorization_change',
      type: 'vectorization',
      direction: dir(d),
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Compute density ' + (d > 0 ? 'increased' : 'decreased') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        arith_fraction_before: feat.before.instruction.arith_fraction,
        arith_fraction_after: feat.after.instruction.arith_fraction,
        before: +sig.before.vectorization.toFixed(3),
        after: +sig.after.vectorization.toFixed(3)
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Loop complexity change                                       */
  /* ================================================================== */
  rules.push(function complexityChange(sig, feat) {
    var d = sig.delta.loop_complexity;
    if (Math.abs(d) < 0.05) return null;
    var conf = Math.min(1, Math.abs(d) * 2);
    return [{
      id: 'loop_complexity_change',
      type: 'structure',
      direction: d < 0 ? 'improved' : 'regressed',
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Loop nest complexity ' + (d < 0 ? 'decreased' : 'increased') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        loops_before: feat.before.loop.count,
        loops_after: feat.after.loop.count,
        max_depth_before: feat.before.loop.max_depth,
        max_depth_after: feat.after.loop.max_depth,
        carried_deps_before: feat.before.loop.loop_carried_count,
        carried_deps_after: feat.after.loop.loop_carried_count
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Execution time / speedup                                     */
  /* ================================================================== */
  rules.push(function speedupRule(sig, feat) {
    var pb = feat.before.performance, pa = feat.after.performance;
    if (!pb || !pa) return null;
    var tb = pb.execution_time, ta = pa.execution_time;
    if (tb == null || ta == null || tb <= 0) return null;
    var ratio = tb / ta;
    var changePct = (1 - ta / tb) * 100;
    if (Math.abs(changePct) < 1) return null;
    var conf = Math.min(1, Math.abs(changePct) / 50);
    return [{
      id: 'execution_speedup',
      type: 'performance',
      direction: ratio >= 1 ? 'improved' : 'regressed',
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: (ratio >= 1 ? 'Speedup' : 'Slowdown') + ' of ' +
        ratio.toFixed(2) + 'x (' + Math.abs(changePct).toFixed(1) + '%)',
      evidence: {
        time_before: tb,
        time_after: ta,
        speedup_ratio: +ratio.toFixed(3),
        runs_averaged: feat.meta.runs
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Instruction count efficiency                                 */
  /* ================================================================== */
  rules.push(function instrCountRule(sig, feat) {
    var ib = feat.before.instruction.total, ia = feat.after.instruction.total;
    if (!ib || !ia) return null;
    var changePct = (ia - ib) / ib * 100;
    if (Math.abs(changePct) < 2) return null;
    var conf = Math.min(1, Math.abs(changePct) / 40);
    return [{
      id: 'instruction_count_change',
      type: 'code_size',
      direction: changePct < 0 ? 'improved' : 'regressed',
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Static instruction count ' + (changePct < 0 ? 'decreased' : 'increased') +
        ' by ' + Math.abs(changePct).toFixed(1) + '% (' + ib + ' → ' + ia + ')',
      evidence: {
        before: ib, after: ia,
        change_pct: +changePct.toFixed(1)
      }
    }];
  });

  /* ================================================================== */
  /*  Rule: Critical-path shift                                          */
  /* ================================================================== */
  rules.push(function critPathRule(sig, feat) {
    var d = sig.delta.critical_path_dominance;
    if (Math.abs(d) < 0.05) return null;
    var conf = Math.min(1, Math.abs(d) * 2);
    return [{
      id: 'critical_path_shift',
      type: 'structure',
      direction: d < 0 ? 'improved' : 'regressed',
      confidence: +conf.toFixed(3),
      impact: impact(conf),
      summary: 'Critical-path share of total cost ' +
        (d < 0 ? 'decreased' : 'increased') +
        ' (Δ=' + (d > 0 ? '+' : '') + d.toFixed(3) + ')',
      evidence: {
        before: +sig.before.critical_path_dominance.toFixed(3),
        after: +sig.after.critical_path_dominance.toFixed(3),
        crit_cost_before: feat.before.cfg.critical_path_cost,
        crit_cost_after: feat.after.cfg.critical_path_cost
      }
    }];
  });

  /* ================================================================== */
  /*  Public API                                                         */
  /* ================================================================== */

  /**
   * Register a custom rule.
   * @param {Function} fn  (signals, features) → Insight[] | null
   */
  function registerRule(fn) {
    if (typeof fn === 'function') rules.push(fn);
  }

  /**
   * Run all registered rules.
   * @param {{ before, after, delta }} signals
   * @param {{ before, after, meta }}  features
   * @returns {Insight[]}
   */
  function evaluate(signals, features) {
    var results = [];
    rules.forEach(function (rule) {
      try {
        var out = rule(signals, features);
        if (out) results = results.concat(out);
      } catch (e) {
        /* swallow – individual rule failure must not crash the engine */
        if (typeof console !== 'undefined') console.warn('[RuleEngine] rule failed:', e);
      }
    });
    results.sort(function (a, b) { return b.confidence - a.confidence; });
    return results;
  }

  ns.RuleEngine = { evaluate: evaluate, registerRule: registerRule };

})(window.InsightEngine = window.InsightEngine || {});
