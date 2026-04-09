/**
 * FeatureExtractor — Phase 1, Module 1
 *
 * Pure function: (irJSON, perfJSON?) → FeatureVector
 *
 * Extracts a flat, normalised feature vector from ll-dump JSON and optional
 * perf_compare.json.  No transformation labels, no heuristics — just facts
 * about the IR and measurements.
 *
 * @module InsightEngine.FeatureExtractor
 */
(function (ns) {
  'use strict';

  /* ------------------------------------------------------------------ */
  /*  helpers                                                            */
  /* ------------------------------------------------------------------ */

  function safeDiv(a, b, fallback) {
    if (fallback === undefined) fallback = 0;
    return b > 0 ? a / b : fallback;
  }

  function parseTripCount(tc) {
    if (typeof tc === 'number') return tc;
    if (typeof tc !== 'string') return NaN;
    var n = parseFloat(tc.replace(/^at most\s*/i, ''));
    return isFinite(n) && n > 0 ? n : NaN;
  }

  /* ------------------------------------------------------------------ */
  /*  loop features                                                      */
  /* ------------------------------------------------------------------ */

  function extractLoopFeatures(fn) {
    var loops = (fn && fn.loops) || [];
    var count = loops.length;
    var maxDepth = 0;
    var knownTrips = [];
    var depCount = 0;
    var loopCarriedCount = 0;
    var totalMemAccesses = 0;
    var stride1Count = 0;
    var stridedCount = 0;
    var unknownPatternCount = 0;
    var loadCount = 0;
    var storeCount = 0;
    var arraySet = {};

    loops.forEach(function (l) {
      if (l.depth > maxDepth) maxDepth = l.depth;
      var tc = parseTripCount(l.trip_count);
      if (isFinite(tc)) knownTrips.push(tc);

      (l.dependencies || []).forEach(function (d) {
        depCount++;
        if (/loop.carried/i.test(d.type || '') || /loop.carried/i.test(d.description || ''))
          loopCarriedCount++;
      });

      (l.memory_accesses || []).forEach(function (m) {
        totalMemAccesses++;
        var pat = (m.pattern || '').toLowerCase();
        if (pat === 'stride-1') stride1Count++;
        else if (pat === 'strided') stridedCount++;
        else unknownPatternCount++;

        var ty = (m.type || '').toLowerCase();
        if (ty === 'load') loadCount++;
        else if (ty === 'store') storeCount++;
        if (m.array) arraySet[m.array] = true;
      });
    });

    return {
      count: count,
      max_depth: maxDepth,
      known_trip_counts: knownTrips,
      mean_trip_count: knownTrips.length ? knownTrips.reduce(function (a, b) { return a + b; }, 0) / knownTrips.length : NaN,
      has_unknown_trip: knownTrips.length < count,
      dependency_count: depCount,
      loop_carried_count: loopCarriedCount,
      memory_access_count: totalMemAccesses,
      stride1_fraction: safeDiv(stride1Count, totalMemAccesses),
      strided_fraction: safeDiv(stridedCount, totalMemAccesses),
      unknown_pattern_fraction: safeDiv(unknownPatternCount, totalMemAccesses),
      load_count: loadCount,
      store_count: storeCount,
      read_write_ratio: safeDiv(loadCount, loadCount + storeCount, 0.5),
      unique_arrays: Object.keys(arraySet).length
    };
  }

  /* ------------------------------------------------------------------ */
  /*  instruction features                                               */
  /* ------------------------------------------------------------------ */

  function extractInstructionFeatures(fn) {
    var total = (fn && fn.instruction_count) || 0;
    var arith = 0, memory = 0, branch = 0, other = 0;
    var nodes = (fn && fn.cfg && fn.cfg.nodes) || [];

    nodes.forEach(function (n) {
      var ins = n.instructions || {};
      arith += ins.arith || 0;
      memory += ins.memory || 0;
      branch += ins.branch || 0;
      other += ins.other || 0;
    });
    var sum = arith + memory + branch + other;
    if (sum === 0) sum = total || 1;

    return {
      total: total,
      arith_fraction: safeDiv(arith, sum),
      memory_fraction: safeDiv(memory, sum),
      branch_fraction: safeDiv(branch, sum),
      other_fraction: safeDiv(other, sum)
    };
  }

  /* ------------------------------------------------------------------ */
  /*  CFG features                                                       */
  /* ------------------------------------------------------------------ */

  function extractCFGFeatures(fn) {
    var cfg = (fn && fn.cfg) || {};
    var nodes = cfg.nodes || [];
    var edges = cfg.edges || [];
    var loops = (fn && fn.loops) || [];
    var headerSet = {};
    loops.forEach(function (l) { if (l.header) headerSet[l.header] = true; });

    var backEdges = 0;
    edges.forEach(function (e) {
      var tgt = nodes.find(function (n) { return n.id === e.to; });
      if (tgt && headerSet[tgt.label]) backEdges++;
    });

    var maxCost = 0, totalCost = 0, critPathCost = 0;
    nodes.forEach(function (n) {
      var c = n.cost || 0;
      totalCost += c;
      if (c > maxCost) maxCost = c;
    });

    loops.forEach(function (l) {
      (l.critical_path || []).forEach(function (label) {
        var nd = nodes.find(function (n) { return n.label === label; });
        if (nd) critPathCost += nd.cost || 0;
      });
    });

    return {
      block_count: nodes.length,
      edge_count: edges.length,
      back_edge_count: backEdges,
      max_block_cost: maxCost,
      total_cost: totalCost,
      critical_path_cost: critPathCost
    };
  }

  /* ------------------------------------------------------------------ */
  /*  performance features                                               */
  /* ------------------------------------------------------------------ */

  function extractPerfFeatures(perfSide) {
    if (!perfSide) return null;
    var f = {};
    var keys = Object.keys(perfSide);
    keys.forEach(function (k) {
      if (typeof perfSide[k] === 'number') f[k] = perfSide[k];
    });
    return f;
  }

  /* ------------------------------------------------------------------ */
  /*  public API                                                         */
  /* ------------------------------------------------------------------ */

  /**
   * Extract a complete FeatureVector from one side (before or after).
   *
   * @param {Object} irJSON   - ll-dump JSON (has `functions` array)
   * @param {Object|null} perfSide - the `before` or `after` object inside perf_compare.json
   * @returns {Object} FeatureVector
   */
  function extract(irJSON, perfSide) {
    var fn = (irJSON && irJSON.functions && irJSON.functions[0]) || null;
    return {
      loop: extractLoopFeatures(fn),
      instruction: extractInstructionFeatures(fn),
      cfg: extractCFGFeatures(fn),
      performance: extractPerfFeatures(perfSide)
    };
  }

  /**
   * Extract paired features (before + after) plus delta metadata.
   *
   * @param {Object} beforeIR  - before ll-dump JSON
   * @param {Object} afterIR   - after ll-dump JSON
   * @param {Object|null} perfJSON - full perf_compare.json (with .before, .after)
   * @returns {{ before: FeatureVector, after: FeatureVector, meta: Object }}
   */
  function extractPair(beforeIR, afterIR, perfJSON) {
    var perf = perfJSON || {};
    var before = extract(beforeIR, perf.before || null);
    var after = extract(afterIR, perf.after || null);
    return {
      before: before,
      after: after,
      meta: {
        profiler: perf.profiler || 'perf',
        device: perf.device || null,
        runs: perf.runs || 1,
        is_gpu: !!(perf.profiler === 'rocprof' || perf.device)
      }
    };
  }

  ns.FeatureExtractor = { extract: extract, extractPair: extractPair };

})(window.InsightEngine = window.InsightEngine || {});
