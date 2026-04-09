/**
 * MLModel — Phase 3 (Skeleton / Research Extension)
 *
 * Data-driven complement to the rule-based engine.  This module defines:
 *   1. A feature-vector schema for training data collection
 *   2. A prediction interface (to be backed by ONNX.js, TF.js, or a remote API)
 *   3. Integration hooks that keep ML output SEPARATE from rule-engine output
 *
 * Current status: SKELETON.  The interface is stable; the model weights and
 * training pipeline are future work (see ENGINE.md § Phase 3).
 *
 * @module InsightEngine.MLModel
 */
(function (ns) {
  'use strict';

  /* ------------------------------------------------------------------ */
  /*  Training-data schema                                               */
  /*  Each row is extracted from one (before, after, perf) triple.       */
  /* ------------------------------------------------------------------ */

  /**
   * Flatten a paired feature + signal set into a fixed-size numeric vector
   * suitable as model input.  All values are already in [0, 1] or normalised.
   *
   * @param {{ before, after, meta }}  features  - from FeatureExtractor.extractPair()
   * @param {{ before, after, delta }} signals   - from SignalComputer.computePair()
   * @returns {{ vector: number[], names: string[] }}
   */
  function featureVector(features, signals) {
    var names = [];
    var vec = [];

    function push(name, val) {
      names.push(name);
      vec.push(isFinite(val) ? val : 0);
    }

    var signalKeys = Object.keys(signals.before);
    signalKeys.forEach(function (k) {
      push('sig_before_' + k, signals.before[k]);
      push('sig_after_' + k, signals.after[k]);
      push('sig_delta_' + k, signals.delta[k]);
    });

    push('loop_count_before', features.before.loop.count);
    push('loop_count_after', features.after.loop.count);
    push('max_depth_before', features.before.loop.max_depth);
    push('max_depth_after', features.after.loop.max_depth);
    push('instr_before', features.before.instruction.total);
    push('instr_after', features.after.instruction.total);
    push('block_count_before', features.before.cfg.block_count);
    push('block_count_after', features.after.cfg.block_count);
    push('is_gpu', features.meta.is_gpu ? 1 : 0);

    if (features.before.performance && features.after.performance) {
      var tb = features.before.performance.execution_time || 0;
      var ta = features.after.performance.execution_time || 0;
      push('speedup_ratio', tb > 0 ? tb / ta : 1);
    }

    return { vector: vec, names: names };
  }

  /* ------------------------------------------------------------------ */
  /*  Prediction interface (stub)                                        */
  /* ------------------------------------------------------------------ */

  /**
   * Predict bottleneck class and expected improvement.
   *
   * Currently returns a placeholder.  Replace with:
   *   - ONNX.js inference (browser)
   *   - TensorFlow.js inference (browser)
   *   - Remote REST call to a Python model server
   *
   * @param {number[]} vec - feature vector from featureVector()
   * @returns {Promise<Object>} ML prediction
   */
  function predict(vec) {
    return Promise.resolve({
      source: 'ml-model',
      status: 'skeleton',
      bottleneck_class: null,
      expected_improvement: null,
      confidence: 0,
      note: 'ML model not yet trained — using rule-engine output only.'
    });
  }

  /* ------------------------------------------------------------------ */
  /*  Training-data collector                                            */
  /*  Call after each analysis to accumulate labelled examples.           */
  /* ------------------------------------------------------------------ */

  var _collected = [];

  /**
   * Record one labelled example for future training.
   *
   * @param {number[]} vec      - feature vector
   * @param {Object}   label    - ground-truth labels
   * @param {string}   label.bottleneck_class  - e.g. "memory-bound"
   * @param {number}   label.speedup           - measured speedup ratio
   */
  function collect(vec, label) {
    _collected.push({ vector: vec, label: label, timestamp: Date.now() });
  }

  /**
   * Export collected training data as JSON string.
   */
  function exportData() {
    return JSON.stringify(_collected, null, 2);
  }

  ns.MLModel = {
    featureVector: featureVector,
    predict: predict,
    collect: collect,
    exportData: exportData
  };

})(window.InsightEngine = window.InsightEngine || {});
