#!/usr/bin/env python3
"""Parse LLVM optimization remarks YAML into JSON for the visualizer.

Usage: python3 parse-remarks.py remarks.yaml remarks.json
"""
import sys, json, re

def parse_remarks_yaml(path):
    """Lightweight YAML-ish parser for LLVM remarks (avoids PyYAML dependency)."""
    remarks = []
    current = None
    with open(path) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('--- !'):
                if current:
                    remarks.append(current)
                kind = line.split('!', 1)[1].strip()
                current = {'kind': kind}
            elif line == '...' or line == '---':
                if current:
                    remarks.append(current)
                    current = None
            elif current is not None:
                m = re.match(r'^(\w[\w-]*):\s*(.*)', line)
                if m:
                    key, val = m.group(1), m.group(2).strip()
                    if val.startswith("'") and val.endswith("'"):
                        val = val[1:-1]
                    elif val.startswith('"') and val.endswith('"'):
                        val = val[1:-1]
                    current[key] = val
    if current:
        remarks.append(current)
    return remarks

def transform_remarks(raw):
    """Convert raw parsed remarks into visualizer-friendly JSON."""
    out = []
    for r in raw:
        entry = {
            'kind': r.get('kind', 'Unknown'),
            'pass_name': r.get('Pass', ''),
            'name': r.get('Name', ''),
            'function': r.get('Function', ''),
        }
        args = []
        for k, v in r.items():
            if k not in ('kind', 'Pass', 'Name', 'Function', 'DebugLoc'):
                args.append({'key': k, 'value': str(v)})
        if args:
            entry['args'] = args
        if 'DebugLoc' in r:
            entry['debug_loc'] = r['DebugLoc']
        out.append(entry)
    return out

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} remarks.yaml remarks.json", file=sys.stderr)
        sys.exit(1)
    raw = parse_remarks_yaml(sys.argv[1])
    result = transform_remarks(raw)
    with open(sys.argv[2], 'w') as f:
        json.dump({'remarks': result}, f, indent=2)
        f.write('\n')
    print(f"Parsed {len(result)} remarks → {sys.argv[2]}")
