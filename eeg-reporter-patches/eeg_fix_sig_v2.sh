#!/bin/bash
# v2: handles the return annotation `def _extract_recording(raw) -> dict:`
set -e
cd ~/eeg-reporter

cp eeg_analyzer.py eeg_analyzer.py.bak-$(date +%Y%m%d-%H%M%S)-pre-sig-v2

python3 - <<'PY'
from pathlib import Path
import ast, re

p = Path.home() / "eeg-reporter/eeg_analyzer.py"
src = p.read_text()

# Match the def line, with or without return annotation, replace it with the
# version that accepts electrodes_map=None.
pattern = re.compile(r"^def _extract_recording\(raw\)(\s*->\s*[^:]+)?:", re.MULTILINE)
m = pattern.search(src)
if m:
    new_line = f"def _extract_recording(raw, electrodes_map=None){m.group(1) or ''}:"
    src = src[:m.start()] + new_line + src[m.end():]
    print(f"Updated def line to: {new_line}")
else:
    # Maybe it's already fixed
    if "_extract_recording(raw, electrodes_map" in src:
        print("Signature already accepts electrodes_map")
    else:
        print("ERROR: could not find def line. Dumping all _extract_recording defs:")
        for ln in src.splitlines():
            if "def _extract_recording" in ln:
                print(f"  {ln!r}")
        raise SystemExit(1)

p.write_text(src)
ast.parse(p.read_text())
print("eeg_analyzer.py PARSES OK")

# Verify
src2 = p.read_text()
for i, ln in enumerate(src2.splitlines(), 1):
    if "def _extract_recording" in ln:
        print(f"Line {i}: {ln}")
PY

tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 5
echo "------ last 10 log lines ------"
tail -10 ~/eeg-reporter/logs/app.log
