/**
 * Proving System — Test Harness
 *
 * Loads all Insight Engine modules into a Node.js context by shimming
 * the `window` global.  Provides assertion helpers and a structured
 * test runner with pass/fail/skip reporting.
 */
'use strict';

const fs   = require('fs');
const path = require('path');
const vm   = require('vm');

/* ── shim browser globals so the IIFE modules can attach to window ── */
const _window = {};
global.window = _window;
global.fetch  = function () { return Promise.reject(new Error('fetch stubbed')); };
global.console = console;

const ENGINE_DIR = path.join(__dirname, '..', 'insight-engine');
const LOAD_ORDER = [
  'feature-extractor.js',
  'signal-computer.js',
  'rule-engine.js',
  'insight-aggregator.js',
  'engine.js',
  'llm-explainer.js',
  'ml-model.js'
];

LOAD_ORDER.forEach(function (f) {
  const code = fs.readFileSync(path.join(ENGINE_DIR, f), 'utf8');
  vm.runInThisContext(code, { filename: f });
});

const IE = _window.InsightEngine;
if (!IE) throw new Error('InsightEngine not found on window after loading modules');

/* ── load every real dataset ── */
const DATASET_DIR = path.join(__dirname, '..', 'datasets');
function loadDataset(name) {
  const dir = path.join(DATASET_DIR, name);
  const read = (f) => {
    const p = path.join(dir, f);
    return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : null;
  };
  return {
    name,
    before: read('before.json'),
    after:  read('after.json'),
    perf:   read('perf_compare.json')
  };
}

const DATASETS = fs.readdirSync(DATASET_DIR)
  .filter(d => fs.statSync(path.join(DATASET_DIR, d)).isDirectory())
  .map(loadDataset)
  .filter(d => d.before && d.after);

/* ── assertion helpers ── */
let _pass = 0, _fail = 0, _skip = 0;
const _failures = [];

function assert(cond, msg) {
  if (cond) { _pass++; }
  else { _fail++; _failures.push(msg); console.error('  ✗ ' + msg); }
}
function assertEq(a, b, msg) {
  assert(a === b, msg + ' (got ' + a + ', expected ' + b + ')');
}
function assertApprox(a, b, eps, msg) {
  assert(Math.abs(a - b) < eps, msg + ' (got ' + a + ', expected ~' + b + ', eps=' + eps + ')');
}
function assertInRange(val, lo, hi, msg) {
  assert(val >= lo && val <= hi, msg + ' (got ' + val + ', expected [' + lo + ',' + hi + '])');
}
function skip(msg) { _skip++; }

function section(title) { console.log('\n═══ ' + title + ' ═══'); }
function subsection(title) { console.log('  ── ' + title); }

function summary() {
  console.log('\n' + '═'.repeat(60));
  console.log('  PASS: ' + _pass + '  FAIL: ' + _fail + '  SKIP: ' + _skip);
  if (_failures.length) {
    console.log('\n  Failures:');
    _failures.forEach(function (f, i) { console.log('    ' + (i + 1) + '. ' + f); });
  }
  console.log('═'.repeat(60));
  return _fail === 0;
}

module.exports = {
  IE, DATASETS, loadDataset,
  assert, assertEq, assertApprox, assertInRange, skip,
  section, subsection, summary,
  getStats: () => ({ pass: _pass, fail: _fail, skip: _skip, failures: _failures })
};
