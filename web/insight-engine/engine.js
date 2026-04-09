/**
 * Engine — Phase 1 Orchestrator
 *
 * Wires FeatureExtractor → SignalComputer → RuleEngine → InsightAggregator
 * into a single call:
 *
 *   InsightEngine.analyze(beforeIR, afterIR, perfJSON?)  →  Report
 *
 * The Report is a complete, deterministic, structured JSON object
 * suitable for both UI rendering and LLM prompting (Phase 2).
 *
 * @module InsightEngine
 */
(function (ns) {
  'use strict';

  /**
   * Run the full Phase-1 pipeline.
   *
   * @param {Object}      beforeIR  - ll-dump JSON for the "before" IR
   * @param {Object}      afterIR   - ll-dump JSON for the "after" IR
   * @param {Object|null} perfJSON  - perf_compare.json (optional)
   * @returns {Object}    Structured report (see ENGINE.md for schema)
   */
  function analyze(beforeIR, afterIR, perfJSON) {
    var FE = ns.FeatureExtractor;
    var SC = ns.SignalComputer;
    var RE = ns.RuleEngine;
    var IA = ns.InsightAggregator;

    var features = FE.extractPair(beforeIR, afterIR, perfJSON);
    var signals = SC.computePair(features);
    var insights = RE.evaluate(signals, features);
    var report = IA.aggregate(insights, signals);

    report.features = features;
    report.version = '1.0.0';
    report.phase = 'rule-based';
    return report;
  }

  /**
   * Single-side signal computation (useful for standalone inspection).
   */
  function signals(irJSON, perfSide, isGpu) {
    var fv = ns.FeatureExtractor.extract(irJSON, perfSide);
    return ns.SignalComputer.compute(fv, !!isGpu);
  }

  ns.analyze = analyze;
  ns.signals = signals;

})(window.InsightEngine = window.InsightEngine || {});
