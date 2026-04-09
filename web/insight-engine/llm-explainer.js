/**
 * LLMExplainer — Phase 2
 *
 * Formatting / explanation layer ONLY.  Takes the structured Phase-1 report
 * and converts it into a prompt + context bundle for an LLM.  The LLM's
 * job is to explain, NOT to reason independently.
 *
 * Design constraints:
 *   1. The LLM never sees raw IR.
 *   2. The LLM receives pre-computed signals, insights, and evidence.
 *   3. The LLM must NOT override rule-engine outputs.
 *   4. API is pluggable: any OpenAI-compatible endpoint (including Ollama,
 *      Anthropic via proxy, etc.) can be used.
 *
 * @module InsightEngine.LLMExplainer
 */
(function (ns) {
  'use strict';

  /* ------------------------------------------------------------------ */
  /*  Prompt construction                                                */
  /* ------------------------------------------------------------------ */

  function buildSystemPrompt() {
    return [
      'You are an expert compiler engineer explaining the results of an automated,',
      'deterministic analysis of an LLVM IR loop transformation.',
      '',
      'Rules you MUST follow:',
      '1. Do NOT invent insights beyond what the analysis provides.',
      '2. Do NOT contradict the rule-engine findings.',
      '3. Explain the provided signals, insights, and bottleneck classification',
      '   in clear, precise language suitable for a compiler researcher.',
      '4. When suggesting further optimisations, ground them in the provided',
      '   evidence (signal values, metric deltas).',
      '5. Keep explanations concise — aim for one paragraph per insight.',
      '6. Use correct compiler terminology.'
    ].join('\n');
  }

  function formatSignals(sig) {
    var lines = ['Signal deltas (after − before, range −1 to +1):'];
    Object.keys(sig.delta).forEach(function (k) {
      var d = sig.delta[k];
      var arrow = d > 0.02 ? '▲' : d < -0.02 ? '▼' : '─';
      lines.push('  ' + k + ': ' + sig.before[k].toFixed(3) +
        ' → ' + sig.after[k].toFixed(3) + '  (' + arrow + ' ' +
        (d > 0 ? '+' : '') + d.toFixed(3) + ')');
    });
    return lines.join('\n');
  }

  function formatInsights(insights) {
    if (!insights.length) return 'No significant rule-based insights detected.';
    return insights.map(function (i, idx) {
      return (idx + 1) + '. [' + i.direction.toUpperCase() + ' — ' +
        i.impact + ' impact, conf=' + i.confidence + '] ' + i.summary +
        '\n   Evidence: ' + JSON.stringify(i.evidence);
    }).join('\n');
  }

  /**
   * Build the full user prompt from a Phase-1 report.
   */
  function buildUserPrompt(report) {
    var sections = [];
    sections.push('## Analysis Summary');
    sections.push('Overall behaviour: ' + report.behaviour);
    sections.push('Bottleneck: ' + report.bottleneck.class +
      ' (score ' + report.bottleneck.score + ')');
    sections.push('Confidence: ' + report.overall_confidence);
    sections.push('');
    sections.push(formatSignals(report.signals));
    sections.push('');
    sections.push('## Improvements (' + report.counts.improved + ')');
    sections.push(formatInsights(report.improved));
    sections.push('');
    sections.push('## Regressions (' + report.counts.regressed + ')');
    sections.push(formatInsights(report.regressed));
    sections.push('');
    sections.push('## Pre-existing expectations');
    report.expected.forEach(function (e) { sections.push('- ' + e); });
    sections.push('');
    sections.push('## Deterministic suggestions');
    report.suggestions.forEach(function (s) { sections.push('- ' + s); });
    sections.push('');
    sections.push('Provide a clear explanation of the transformation\'s effects,');
    sections.push('grounded strictly in the above data. Then list 2-3 actionable');
    sections.push('next steps a compiler engineer should consider.');
    return sections.join('\n');
  }

  /* ------------------------------------------------------------------ */
  /*  LLM call (pluggable)                                               */
  /* ------------------------------------------------------------------ */

  /**
   * Call an OpenAI-compatible chat completions endpoint.
   *
   * @param {Object} opts
   * @param {string} opts.endpoint - full URL to /v1/chat/completions
   * @param {string} opts.apiKey
   * @param {string} opts.model    - e.g. "gpt-4o", "claude-3.5-sonnet"
   * @param {Object} report        - Phase-1 report
   * @param {Object} [extraHeaders] - additional request headers
   * @returns {Promise<string>}    - the LLM explanation text
   */
  function explain(opts, report, extraHeaders) {
    var messages = [
      { role: 'system', content: buildSystemPrompt() },
      { role: 'user', content: buildUserPrompt(report) }
    ];
    var headers = { 'Content-Type': 'application/json' };
    if (opts.apiKey) headers['Authorization'] = 'Bearer ' + opts.apiKey;
    if (extraHeaders) Object.keys(extraHeaders).forEach(function (k) { headers[k] = extraHeaders[k]; });

    return fetch(opts.endpoint, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify({
        model: opts.model || 'gpt-4o',
        messages: messages,
        temperature: 0.3,
        max_tokens: 1500
      })
    })
    .then(function (r) {
      if (!r.ok) return r.text().then(function (t) { throw new Error('LLM API ' + r.status + ': ' + t); });
      return r.json();
    })
    .then(function (j) {
      var c = j.choices && j.choices[0] && j.choices[0].message;
      return c ? c.content : '(no response)';
    });
  }

  /**
   * Generate a purely local (no-network) fallback explanation from the
   * Phase-1 report.  Useful when no API key is available.
   */
  function explainOffline(report) {
    var lines = [];
    lines.push('Behaviour: ' + report.behaviour + '.');
    lines.push('Bottleneck class: ' + report.bottleneck.class + '.');
    lines.push('');
    if (report.improved.length) {
      lines.push('What improved:');
      report.improved.forEach(function (i) {
        lines.push('  • ' + i.summary + ' (confidence ' + i.confidence + ')');
      });
    }
    if (report.regressed.length) {
      lines.push('What regressed:');
      report.regressed.forEach(function (i) {
        lines.push('  • ' + i.summary + ' (confidence ' + i.confidence + ')');
      });
    }
    lines.push('');
    lines.push('Suggestions:');
    report.suggestions.forEach(function (s) { lines.push('  • ' + s); });
    return lines.join('\n');
  }

  ns.LLMExplainer = {
    buildSystemPrompt: buildSystemPrompt,
    buildUserPrompt: buildUserPrompt,
    explain: explain,
    explainOffline: explainOffline
  };

})(window.InsightEngine = window.InsightEngine || {});
