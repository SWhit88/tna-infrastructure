#!/bin/bash
# Targeted: fix the _extract_recording signature so it accepts the
# electrodes_map kwarg that analyze() is now passing. v3 patched the
# CALL but missed the actual def — confirming with grep first.
set -e
cd ~/eeg-reporter

echo "=========== Current def of _extract_recording ==========="
grep -n "def _extract_recording" eeg_analyzer.py || echo "(not found)"
echo
echo "=========== Current call site(s) ==========="
grep -n "_extract_recording(" eeg_analyzer.py
echo
echo "=========== Current n_channels expression ==========="
grep -n "n_channels" eeg_analyzer.py | head -10
echo

# Make a backup before touching
cp eeg_analyzer.py eeg_analyzer.py.bak-$(date +%Y%m%d-%H%M%S)-pre-sig-fix

python3 - <<'PY'
from pathlib import Path
import ast

p = Path.home() / "eeg-reporter/eeg_analyzer.py"
src = p.read_text()

# 1. Force the def signature.
old_def = "def _extract_recording(raw):"
new_def = "def _extract_recording(raw, electrodes_map=None):"
if old_def in src:
    src = src.replace(old_def, new_def, 1)
    print("Updated _extract_recording signature")
elif new_def in src:
    print("Signature already correct")
else:
    print("WARNING: neither signature variant found — dumping defs:")
    for ln in src.splitlines():
        if "_extract_recording" in ln:
            print(f"  {ln!r}")

# 2. Make sure the dict body uses electrodes_map (the parameter), not result.get().
# This matches whatever v3 left in place.
bad = '"n_channels": _count_scalp_channels(raw, result.get("electrodes", {}))'
fixed = '"n_channels": _count_scalp_channels(raw, electrodes_map or {})'
if bad in src:
    src = src.replace(bad, fixed, 1)
    print("Switched n_channels expression to use electrodes_map param")
elif fixed in src:
    print("n_channels expression already uses electrodes_map")

p.write_text(src)
ast.parse(p.read_text())
print("eeg_analyzer.py PARSES OK")
PY

# Restart the watcher so changes take effect in the live process
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 5
echo "------ last 10 log lines ------"
tail -10 ~/eeg-reporter/logs/app.log
