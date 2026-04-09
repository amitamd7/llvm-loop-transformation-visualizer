#!/usr/bin/env python3
"""
validate_json.py — Deep structural validator for ll-dump JSON,
perf_compare.json, and Insight Engine contracts.

Usage:
  python3 validate_json.py before.json after.json [perf_compare.json]

Returns exit code 0 if ALL checks pass, 1 otherwise.
Prints structured PASS / FAIL / WARN lines for every check.
"""

import json
import sys
import os


class Validator:
    def __init__(self):
        self.passes = 0
        self.fails = 0
        self.warns = 0
        self.failures = []

    def check(self, condition, tag, msg):
        if condition:
            self.passes += 1
        else:
            self.fails += 1
            self.failures.append(f"  FAIL [{tag}] {msg}")
            print(f"  FAIL [{tag}] {msg}")

    def warn(self, condition, tag, msg):
        if not condition:
            self.warns += 1
            print(f"  WARN [{tag}] {msg}")

    def summary(self):
        total = self.passes + self.fails
        print(f"\n  Result: {self.passes}/{total} passed, {self.fails} failed, {self.warns} warnings")
        return self.fails == 0


def load_json(path):
    with open(path, 'r') as f:
        return json.load(f)


def validate_ir_json(v, data, label):
    """Validate a before.json / after.json from ll-dump."""

    v.check(isinstance(data, dict), f"{label}.root", "root must be object")
    v.check("functions" in data, f"{label}.functions", "'functions' key required")

    fns = data.get("functions", [])
    v.check(isinstance(fns, list), f"{label}.functions_type", "'functions' must be array")
    v.check(len(fns) > 0, f"{label}.functions_nonempty", "at least one function expected")

    for fi, fn in enumerate(fns):
        fn_tag = f"{label}.fn[{fi}]"
        v.check("name" in fn, f"{fn_tag}.name", "function must have 'name'")
        v.check(isinstance(fn.get("name", ""), str), f"{fn_tag}.name_type", "'name' must be string")

        fname = fn.get("name", f"fn{fi}")

        v.check("instruction_count" in fn, f"{fn_tag}.instr_count",
                 f"'{fname}' missing 'instruction_count'")
        ic = fn.get("instruction_count", 0)
        v.check(isinstance(ic, (int, float)), f"{fn_tag}.instr_count_type",
                 f"'{fname}' instruction_count must be number")

        # Skip declarations (instruction_count == 0)
        if ic == 0:
            continue

        v.check(ic > 0, f"{fn_tag}.instr_count_positive",
                 f"'{fname}' instruction_count should be > 0 for definitions")

        # --- CFG ---
        v.check("cfg" in fn, f"{fn_tag}.cfg", f"'{fname}' missing 'cfg'")
        cfg = fn.get("cfg", {})
        v.check("nodes" in cfg, f"{fn_tag}.cfg.nodes", f"'{fname}' cfg missing 'nodes'")
        v.check("edges" in cfg, f"{fn_tag}.cfg.edges", f"'{fname}' cfg missing 'edges'")

        nodes = cfg.get("nodes", [])
        edges = cfg.get("edges", [])
        v.check(len(nodes) > 0, f"{fn_tag}.nodes_nonempty",
                 f"'{fname}' must have at least 1 CFG node")

        node_ids = set()
        node_labels = set()
        for ni, n in enumerate(nodes):
            ntag = f"{fn_tag}.node[{ni}]"
            v.check("id" in n, f"{ntag}.id", "node missing 'id'")
            v.check("label" in n, f"{ntag}.label", "node missing 'label'")
            v.check("instructions" in n, f"{ntag}.instructions", "node missing 'instructions'")
            v.check("cost" in n, f"{ntag}.cost", "node missing 'cost'")
            v.check("impact" in n, f"{ntag}.impact", "node missing 'impact'")

            nid = n.get("id", "")
            node_ids.add(nid)
            node_labels.add(n.get("label", ""))

            instr = n.get("instructions", {})
            for key in ["total", "arith", "memory", "branch", "other"]:
                v.check(key in instr, f"{ntag}.instr.{key}",
                         f"node '{nid}' instructions missing '{key}'")
                val = instr.get(key, -1)
                v.check(isinstance(val, (int, float)) and val >= 0,
                         f"{ntag}.instr.{key}_valid",
                         f"node '{nid}' instructions.{key} must be >= 0, got {val}")

            total = instr.get("total", 0)
            parts = (instr.get("arith", 0) + instr.get("memory", 0) +
                     instr.get("branch", 0) + instr.get("other", 0))
            v.check(total == parts, f"{ntag}.instr_sum",
                     f"node '{nid}' total={total} != sum of parts={parts}")

            cost = n.get("cost", -1)
            v.check(isinstance(cost, (int, float)) and cost >= 0,
                     f"{ntag}.cost_valid", f"node '{nid}' cost must be >= 0")
            impact = n.get("impact", -1)
            v.check(isinstance(impact, (int, float)) and impact >= 0,
                     f"{ntag}.impact_valid", f"node '{nid}' impact must be >= 0")

        for ei, e in enumerate(edges):
            etag = f"{fn_tag}.edge[{ei}]"
            v.check("from" in e, f"{etag}.from", "edge missing 'from'")
            v.check("to" in e, f"{etag}.to", "edge missing 'to'")
            v.check(e.get("from", "") in node_ids, f"{etag}.from_valid",
                     f"edge 'from'='{e.get('from','')}' not in node ids")
            v.check(e.get("to", "") in node_ids, f"{etag}.to_valid",
                     f"edge 'to'='{e.get('to','')}' not in node ids")

        # --- Loops ---
        v.check("loops" in fn, f"{fn_tag}.loops", f"'{fname}' missing 'loops'")
        loops = fn.get("loops", [])
        v.check(isinstance(loops, list), f"{fn_tag}.loops_type", "'loops' must be array")

        for li, lp in enumerate(loops):
            ltag = f"{fn_tag}.loop[{li}]"
            for key in ["id", "header", "depth", "trip_count",
                        "induction_variable", "blocks",
                        "memory_accesses", "dependencies", "critical_path"]:
                v.check(key in lp, f"{ltag}.{key}", f"loop missing '{key}'")

            lid = lp.get("id", f"loop{li}")

            depth = lp.get("depth", -1)
            v.check(isinstance(depth, (int, float)) and depth >= 1,
                     f"{ltag}.depth_valid", f"loop '{lid}' depth must be >= 1, got {depth}")

            blocks = lp.get("blocks", [])
            v.check(isinstance(blocks, list) and len(blocks) > 0,
                     f"{ltag}.blocks_nonempty", f"loop '{lid}' blocks must be non-empty")

            header = lp.get("header", "")
            v.check(header in node_labels, f"{ltag}.header_in_cfg",
                     f"loop '{lid}' header '{header}' not in CFG node labels")
            for blk in blocks:
                v.check(blk in node_labels, f"{ltag}.block_in_cfg",
                         f"loop '{lid}' block '{blk}' not in CFG node labels")

            tc = lp.get("trip_count", "")
            v.check(isinstance(tc, str), f"{ltag}.trip_count_type",
                     f"loop '{lid}' trip_count must be string, got {type(tc).__name__}")

            iv = lp.get("induction_variable", "")
            v.check(isinstance(iv, str), f"{ltag}.iv_type",
                     f"loop '{lid}' induction_variable must be string")

            # Memory accesses
            ma = lp.get("memory_accesses", [])
            v.check(isinstance(ma, list), f"{ltag}.memaccess_type", "memory_accesses must be array")
            for mi, m in enumerate(ma):
                mtag = f"{ltag}.memaccess[{mi}]"
                v.check("type" in m, f"{mtag}.type", "memory access missing 'type'")
                v.check("array" in m, f"{mtag}.array", "memory access missing 'array'")
                v.check("pattern" in m, f"{mtag}.pattern", "memory access missing 'pattern'")
                mtype = m.get("type", "")
                v.check(mtype in ("load", "store"), f"{mtag}.type_valid",
                         f"memory access type must be 'load' or 'store', got '{mtype}'")
                pat = m.get("pattern", "")
                v.check(pat in ("stride-1", "strided", "unknown"), f"{mtag}.pattern_valid",
                         f"memory access pattern must be stride-1/strided/unknown, got '{pat}'")

            # Dependencies
            deps = lp.get("dependencies", [])
            v.check(isinstance(deps, list), f"{ltag}.deps_type", "dependencies must be array")
            for di, d in enumerate(deps):
                dtag = f"{ltag}.dep[{di}]"
                v.check("type" in d, f"{dtag}.type", "dependency missing 'type'")
                v.check("description" in d, f"{dtag}.description", "dependency missing 'description'")
                dtype = d.get("type", "")
                v.check(dtype in ("flow", "anti", "output", "loop-carried"),
                         f"{dtag}.type_valid",
                         f"dependency type must be flow/anti/output/loop-carried, got '{dtype}'")

            # Critical path
            cp = lp.get("critical_path", [])
            v.check(isinstance(cp, list), f"{ltag}.critpath_type",
                     "critical_path must be array")
            for blk in cp:
                v.check(blk in node_labels, f"{ltag}.critpath_block",
                         f"critical_path block '{blk}' not in CFG node labels")


def validate_cfg_diff(v, before_data, after_data):
    """Validate that diff computation would work correctly."""
    bf = before_data.get("functions", [])
    af = after_data.get("functions", [])

    # Only consider defined functions (skip intrinsics / declarations)
    bf_defined = {f["name"] for f in bf if f.get("instruction_count", 0) > 0}
    af_defined = {f["name"] for f in af if f.get("instruction_count", 0) > 0}
    shared = bf_defined & af_defined
    v.check(len(shared) > 0, "diff.shared_functions",
             f"before/after must share at least 1 defined function name. before={bf_defined}, after={af_defined}")

    for fname in shared:
        bf_fn = next(f for f in bf if f.get("name") == fname)
        af_fn = next(f for f in af if f.get("name") == fname)

        bf_labels = {n["label"] for n in bf_fn.get("cfg", {}).get("nodes", []) if "label" in n}
        af_labels = {n["label"] for n in af_fn.get("cfg", {}).get("nodes", []) if "label" in n}

        v.check(len(bf_labels) > 0, f"diff.{fname}.before_nodes",
                 f"'{fname}' before has no CFG nodes")
        v.check(len(af_labels) > 0, f"diff.{fname}.after_nodes",
                 f"'{fname}' after has no CFG nodes")

        v.warn(len(bf_labels & af_labels) > 0, f"diff.{fname}.unchanged",
               f"'{fname}': zero unchanged blocks (entirely rewritten)")


def validate_loop_detection(v, data, label):
    """Check loops are properly detected for non-trivial functions."""
    for fn in data.get("functions", []):
        fname = fn.get("name", "?")
        if fn.get("instruction_count", 0) == 0:
            continue
        loops = fn.get("loops", [])
        nodes = fn.get("cfg", {}).get("nodes", [])
        edges = fn.get("cfg", {}).get("edges", [])

        has_backedge = False
        node_label_to_id = {}
        id_to_label = {}
        for n in nodes:
            node_label_to_id[n.get("label", "")] = n.get("id", "")
            id_to_label[n.get("id", "")] = n.get("label", "")

        loop_headers = {lp.get("header", "") for lp in loops}
        for e in edges:
            target_label = id_to_label.get(e.get("to", ""), "")
            source_label = id_to_label.get(e.get("from", ""), "")
            if target_label in loop_headers:
                for lp in loops:
                    if lp.get("header") == target_label:
                        if source_label in lp.get("blocks", []):
                            has_backedge = True
                            break

        if len(loops) > 0:
            v.check(has_backedge, f"{label}.{fname}.backedge",
                     f"'{fname}' has {len(loops)} loops but no back-edge detected in edges")

        for lp in loops:
            lid = lp.get("id", "")
            blocks = lp.get("blocks", [])
            header = lp.get("header", "")
            v.check(header in blocks, f"{label}.{fname}.{lid}.header_in_blocks",
                     f"loop header '{header}' must be in its own blocks list")

            cp = lp.get("critical_path", [])
            if len(cp) > 0:
                for blk in cp:
                    v.check(blk in blocks, f"{label}.{fname}.{lid}.cp_subset",
                             f"critical_path block '{blk}' must be within loop blocks")


def validate_perf(v, perf):
    """Validate perf_compare.json structure."""
    v.check(isinstance(perf, dict), "perf.root", "perf must be object")
    v.check("before" in perf, "perf.before", "'before' key required")
    v.check("after" in perf, "perf.after", "'after' key required")

    before = perf.get("before", {})
    after = perf.get("after", {})
    v.check(isinstance(before, dict), "perf.before_type", "'before' must be object")
    v.check(isinstance(after, dict), "perf.after_type", "'after' must be object")

    runs = perf.get("runs", 0)
    v.warn(isinstance(runs, (int, float)) and runs >= 1, "perf.runs",
           f"'runs' should be >= 1, got {runs}")

    profiler = perf.get("profiler", "perf")
    is_gpu = profiler == "rocprof" or bool(perf.get("device"))

    cpu_keys = ["execution_time", "cycles", "instructions", "ipc",
                "l1_miss_rate", "branch_miss_rate"]
    gpu_keys = ["execution_time", "valu_insts", "salu_insts", "vmem_insts",
                "waves", "l2_hit_rate", "instructions"]

    expected = gpu_keys if is_gpu else cpu_keys

    for side_name, side in [("before", before), ("after", after)]:
        if not side:
            continue
        found = [k for k in expected if k in side and isinstance(side[k], (int, float))]
        v.check(len(found) > 0, f"perf.{side_name}.has_metrics",
                 f"perf '{side_name}' has no recognized metrics from {expected}")
        for k in found:
            val = side[k]
            v.check(val >= 0, f"perf.{side_name}.{k}_nonneg",
                     f"perf {side_name}.{k} = {val} must be >= 0")

    if "execution_time" in before and "execution_time" in after:
        bt = before["execution_time"]
        at = after["execution_time"]
        if bt > 0 and at > 0:
            ratio = bt / at
            v.warn(0.01 < ratio < 100, "perf.speedup_sane",
                   f"speedup ratio {ratio:.2f}x seems extreme")


def validate_insight_engine_contract(v, before_data, after_data, perf_data):
    """Verify the Insight Engine would succeed on this data."""
    bf = before_data.get("functions", [])
    af = after_data.get("functions", [])

    v.check(len(bf) > 0, "engine.before_has_fn",
             "Insight Engine needs at least 1 function in before")
    v.check(len(af) > 0, "engine.after_has_fn",
             "Insight Engine needs at least 1 function in after")

    if len(bf) > 0 and len(af) > 0:
        bf0 = bf[0]
        af0 = af[0]
        v.check(bf0.get("instruction_count", 0) > 0, "engine.before_fn0_has_instrs",
                 "Engine uses functions[0] — must have instructions")
        v.check(af0.get("instruction_count", 0) > 0, "engine.after_fn0_has_instrs",
                 "Engine uses functions[0] — must have instructions")

        for side, name in [(bf0, "before"), (af0, "after")]:
            v.check("cfg" in side, f"engine.{name}_has_cfg", f"Engine needs cfg on {name}")
            cfg = side.get("cfg", {})
            v.check(len(cfg.get("nodes", [])) > 0, f"engine.{name}_has_nodes",
                     f"Engine needs nodes in {name} cfg")

    if perf_data and perf_data.get("before") and perf_data.get("after"):
        for side_name in ["before", "after"]:
            side = perf_data.get(side_name, {})
            numerics = {k: v for k, v in side.items() if isinstance(v, (int, float))}
            v.warn(len(numerics) > 0, f"engine.perf_{side_name}_numerics",
                   f"Engine perf {side_name} has no numeric values")


def validate_consistency(v, before_data, after_data):
    """Cross-check before/after for internal consistency."""
    bf = before_data.get("functions", [])
    af = after_data.get("functions", [])

    for fn in bf + af:
        fname = fn.get("name", "?")
        ic = fn.get("instruction_count", 0)
        if ic == 0:
            continue
        nodes = fn.get("cfg", {}).get("nodes", [])
        node_sum = sum(n.get("instructions", {}).get("total", 0) for n in nodes)
        v.check(ic == node_sum, f"consistency.{fname}.instr_count",
                 f"'{fname}' instruction_count={ic} but sum of node totals={node_sum}")


def main():
    if len(sys.argv) < 3:
        print("Usage: validate_json.py before.json after.json [perf_compare.json]")
        sys.exit(2)

    before_path = sys.argv[1]
    after_path = sys.argv[2]
    perf_path = sys.argv[3] if len(sys.argv) > 3 else None

    v = Validator()

    for path in [before_path, after_path]:
        v.check(os.path.exists(path), f"file.{os.path.basename(path)}",
                 f"file not found: {path}")

    if v.fails > 0:
        v.summary()
        sys.exit(1)

    try:
        before_data = load_json(before_path)
    except Exception as e:
        v.check(False, "parse.before", f"failed to parse before JSON: {e}")
        v.summary()
        sys.exit(1)

    try:
        after_data = load_json(after_path)
    except Exception as e:
        v.check(False, "parse.after", f"failed to parse after JSON: {e}")
        v.summary()
        sys.exit(1)

    perf_data = None
    if perf_path and os.path.exists(perf_path):
        try:
            perf_data = load_json(perf_path)
        except Exception as e:
            v.check(False, "parse.perf", f"failed to parse perf JSON: {e}")

    print(f"=== Validating before: {before_path}")
    validate_ir_json(v, before_data, "before")

    print(f"=== Validating after:  {after_path}")
    validate_ir_json(v, after_data, "after")

    print("=== Validating CFG diff compatibility")
    validate_cfg_diff(v, before_data, after_data)

    print("=== Validating loop detection")
    validate_loop_detection(v, before_data, "before")
    validate_loop_detection(v, after_data, "after")

    print("=== Validating internal consistency")
    validate_consistency(v, before_data, after_data)

    if perf_data:
        print(f"=== Validating perf:   {perf_path}")
        validate_perf(v, perf_data)

    print("=== Validating Insight Engine contract")
    validate_insight_engine_contract(v, before_data, after_data, perf_data)

    ok = v.summary()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
