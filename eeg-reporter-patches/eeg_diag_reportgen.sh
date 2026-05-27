#!/bin/bash
# Quick: list public symbols in report_generator.py and show its top-level defs.
set -e
cd ~/eeg-reporter
echo "=========== Top-level def/class in report_generator.py ==========="
grep -nE '^(def|class) ' report_generator.py | head -40
echo
echo "=========== Module __all__ or callable members ==========="
python3 - <<'PY'
import sys
sys.path.insert(0, "/home/leige/eeg-reporter")
import report_generator as rg
print("Public callables:")
for name in dir(rg):
    if name.startswith("_"):
        continue
    obj = getattr(rg, name)
    if callable(obj):
        print(f"  {name}  -- {getattr(obj,'__module__','?')}")
PY
