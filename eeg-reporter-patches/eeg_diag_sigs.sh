#!/usr/bin/env bash
# Print the exact @app.callback decorator + function signature for the
# three mismatched callbacks: show_report, do_sign, do_unlock.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

python3 - <<'PY'
import ast, pathlib, sys
p = pathlib.Path.home() / "eeg-reporter" / "app.py"
src = p.read_text()
tree = ast.parse(src)
targets = {"show_report", "do_sign", "do_unlock"}
lines = src.splitlines()
for node in ast.walk(tree):
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name in targets:
        # find earliest decorator line
        if node.decorator_list:
            start = min(d.lineno for d in node.decorator_list)
        else:
            start = node.lineno
        end = node.body[0].lineno - 1 if node.body else node.lineno
        # extend end to include the function header (in case signature is multi-line)
        end = max(end, node.lineno)
        print("="*70)
        print(f"# {node.name}  lines {start}-{end}")
        print("="*70)
        for i in range(start, end + 1):
            print(f"{i:5d}: {lines[i-1]}")
        print()
PY
