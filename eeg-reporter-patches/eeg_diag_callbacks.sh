#!/bin/bash
# Print every registered callback signature so we can spot any mismatched
# Input/State/Output count between declared decorator and function params.
set -e
cd ~/eeg-reporter

python3 - <<'PY'
import sys, re
from pathlib import Path
src = (Path.home() / "eeg-reporter/app.py").read_text()

# Find every @app.callback(...) block and its following def
pattern = re.compile(
    r"@app\.callback\((.*?)\)\s*\ndef\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\((.*?)\):",
    re.DOTALL,
)
matches = pattern.findall(src)
print(f"Registered callbacks: {len(matches)}\n")
for i, (deco, name, params) in enumerate(matches, 1):
    n_inputs  = deco.count("Input(")
    n_outputs = deco.count("Output(")
    n_states  = deco.count("State(") + deco.count("dash.State(")
    # crude param count: split on top-level commas
    param_list = [p.strip() for p in params.split(",") if p.strip()]
    n_params = len(param_list)
    n_decl   = n_inputs + n_states
    flag = "OK" if n_params == n_decl else f"MISMATCH (decl={n_decl}, params={n_params})"
    print(f"[{i}] {name}: In={n_inputs} State={n_states} Out={n_outputs} params={n_params}  {flag}")
PY

echo
echo "=========== All ids referenced in callback decorators ==========="
grep -oE '(Input|Output|State|dash\.State)\("[a-z0-9-]+"' app.py | sed -E 's/.*"([^"]+)"/\1/' | sort -u

echo
echo "=========== All component ids defined in the layout ==========="
grep -oE 'id="[a-z0-9-]+"' app.py | sed -E 's/.*"([^"]+)".*/\1/' | sort -u
