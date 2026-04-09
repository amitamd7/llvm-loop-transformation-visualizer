/**
 * SignalComputer — Phase 1, Module 2
 *
 * Pure function: (FeatureVector) → SignalVector
 *
 * Computes continuous signals in [0, 1] from raw features.
 * Each signal has a clear mathematical definition documented inline.
 * Signals are computed independently for before/after; the delta is a
 * separate concern handled by the RuleEngine.
 *
 * Design note: GPU and CPU share the same signal names but the underlying
 * formulas branch on `meta.is_gpu` to use the appropriate counters.
 *
 * @module InsightEngine.SignalComputer
 */
(function (ns) {
  'use strict';

  function clamp01(x) { return isFinite(x) ? Math.max(0, Math.min(1, x)) : 0; }
  function safeDiv(a, b, f) { return b > 0 ? a / b : (f === undefined ? 0 : f); }

  /* ================================================================== */
  /*  Individual signal functions                                        */
  /*  Each returns a number in [0, 1] where higher is "better" unless    */
  /*  stated otherwise.                                                  */
  /* ================================================================== */

  /**
   * Locality score  [0, 1]  —  higher = better spatial locality.
   *
   * CPU: weighted combination of stride-1 fraction and (1 − L1 miss rate/100).
   * GPU: L2 hit rate directly represents cache locality.
   * If no perf data: fall back to IR-only stride-1 fraction.
   *
   * Formula (CPU):
   *   locality = 0.6 × stride1_fraction + 0.4 × (1 − l1_miss_rate / 100)
   */
  function localityScore(fv, isGpu) {
    var stride = fv.loop.stride1_fraction;
    var p = fv.performance;
    if (isGpu && p && p.l2_hit_rate != null)
      return clamp01(0.4 * stride + 0.6 * p.l2_hit_rate);
    if (p && p.l1_miss_rate != null)
      return clamp01(0.6 * stride + 0.4 * (1 - p.l1_miss_rate / 100));
    return clamp01(stride);
  }

  /**
   * Cache efficiency  [0, 1]  —  higher = fewer misses.
   *
   * CPU: harmonic mean of (1 − L1%) and (1 − LLC%).
   * GPU: L2 hit rate.
   */
  function cacheEfficiencyScore(fv, isGpu) {
    var p = fv.performance;
    if (!p) return 0.5;
    if (isGpu) return clamp01(p.l2_hit_rate != null ? p.l2_hit_rate : 0.5);
    var a = p.l1_miss_rate != null ? 1 - p.l1_miss_rate / 100 : 0.9;
    var b = p.llc_miss_rate != null ? 1 - p.llc_miss_rate / 100 : 0.9;
    a = clamp01(a);
    b = clamp01(b);
    return clamp01(a * b > 0 ? 2 * a * b / (a + b) : 0);
  }

  /**
   * Parallelism score  [0, 1]  —  higher = more ILP / occupancy.
   *
   * CPU: IPC / peak (assume peak ≈ 6 for a modern wide-issue core).
   * GPU: waves / reference_max (1024 as a reasonable MI-class default).
   */
  var CPU_PEAK_IPC = 6;
  var GPU_REF_WAVES = 1024;

  function parallelismScore(fv, isGpu) {
    var p = fv.performance;
    if (!p) return 0.5;
    if (isGpu && p.waves != null)
      return clamp01(p.waves / GPU_REF_WAVES);
    if (p.ipc != null)
      return clamp01(p.ipc / CPU_PEAK_IPC);
    return 0.5;
  }

  /**
   * Vectorization score  [0, 1]  —  higher = more SIMD-like behaviour.
   *
   * Proxy: ratio of arithmetic instructions to total, combined with
   * low branch fraction (vectorized code has straight-line compute).
   * GPU: VALU fraction of total issue slots.
   */
  function vectorizationScore(fv, isGpu) {
    var ins = fv.instruction;
    var p = fv.performance;
    if (isGpu && p && p.valu_insts != null && p.instructions > 0)
      return clamp01(p.valu_insts / p.instructions);
    var arithHeavy = ins.arith_fraction;
    var branchLight = 1 - ins.branch_fraction;
    return clamp01(0.7 * arithHeavy + 0.3 * branchLight);
  }

  /**
   * Memory pressure  [0, 1]  —  higher = MORE memory-bound (this is
   * an anti-signal: higher is worse for throughput).
   *
   * CPU: memory fraction of instructions + cache miss contribution.
   * GPU: VMEM + SMEM fraction of total instructions.
   */
  function memoryPressureScore(fv, isGpu) {
    var ins = fv.instruction;
    var p = fv.performance;
    if (isGpu && p) {
      var memInsts = (p.vmem_insts || 0) + (p.smem_insts || 0) + (p.lds_insts || 0);
      return clamp01(safeDiv(memInsts, p.instructions || 1));
    }
    var base = ins.memory_fraction;
    if (p) {
      var missContrib = ((p.l1_miss_rate || 0) + (p.llc_miss_rate || 0)) / 200;
      return clamp01(0.6 * base + 0.4 * missContrib);
    }
    return clamp01(base);
  }

  /**
   * Branch overhead  [0, 1]  —  higher = MORE branch stalls.
   *
   * CPU: branch_miss_rate / 100.
   * GPU: SALU fraction (scalar control flow).
   */
  function branchOverheadScore(fv, isGpu) {
    var p = fv.performance;
    if (isGpu && p && p.salu_insts != null)
      return clamp01(safeDiv(p.salu_insts, p.instructions || 1));
    if (p && p.branch_miss_rate != null)
      return clamp01(p.branch_miss_rate / 100);
    return clamp01(fv.instruction.branch_fraction);
  }

  /**
   * Loop complexity  [0, 1]  —  higher = more complex nest.
   *
   * Combines depth, dependency density, and unknown-trip fraction.
   * Depth of 4+ maps to 1.0.
   */
  function loopComplexityScore(fv) {
    var l = fv.loop;
    var depthTerm = clamp01(l.max_depth / 4);
    var depTerm = clamp01(safeDiv(l.loop_carried_count, l.dependency_count || 1));
    var unknownTerm = l.has_unknown_trip ? 0.5 : 0;
    return clamp01(0.4 * depthTerm + 0.4 * depTerm + 0.2 * unknownTerm);
  }

  /**
   * Critical path dominance  [0, 1]  —  fraction of total CFG cost
   * on the critical path.
   */
  function criticalPathDominance(fv) {
    return clamp01(safeDiv(fv.cfg.critical_path_cost, fv.cfg.total_cost));
  }

  /* ================================================================== */
  /*  Public API                                                         */
  /* ================================================================== */

  /**
   * Compute all signals for a single FeatureVector.
   * @param {Object} fv   - FeatureVector from FeatureExtractor.extract()
   * @param {boolean} isGpu
   * @returns {Object} SignalVector  — keys are signal names, values in [0,1]
   */
  function compute(fv, isGpu) {
    return {
      locality:             localityScore(fv, isGpu),
      cache_efficiency:     cacheEfficiencyScore(fv, isGpu),
      parallelism:          parallelismScore(fv, isGpu),
      vectorization:        vectorizationScore(fv, isGpu),
      memory_pressure:      memoryPressureScore(fv, isGpu),
      branch_overhead:      branchOverheadScore(fv, isGpu),
      loop_complexity:      loopComplexityScore(fv),
      critical_path_dominance: criticalPathDominance(fv)
    };
  }

  /**
   * Compute paired signals + deltas.
   * Delta = after − before  (positive means the signal increased).
   *
   * @param {Object} pair  - output of FeatureExtractor.extractPair()
   * @returns {{ before: SignalVector, after: SignalVector, delta: SignalVector }}
   */
  function computePair(pair) {
    var isGpu = pair.meta.is_gpu;
    var sb = compute(pair.before, isGpu);
    var sa = compute(pair.after, isGpu);
    var delta = {};
    Object.keys(sb).forEach(function (k) {
      delta[k] = +(sa[k] - sb[k]).toFixed(6);
    });
    return { before: sb, after: sa, delta: delta };
  }

  ns.SignalComputer = { compute: compute, computePair: computePair };

})(window.InsightEngine = window.InsightEngine || {});
