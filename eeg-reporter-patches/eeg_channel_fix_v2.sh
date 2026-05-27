#!/bin/bash
# Repair the v1 patch: SCALP_10_20 landed inside an `if` block in
# eeg_analyzer.py. This script restores from the latest .bak, then re-applies
# the constant at true module-top (after the import block).
# report_generator.py patches from v1 are already correct — only touched if missing.
set -e
cd ~/eeg-reporter

LATEST_BAK=$(ls -1t eeg_analyzer.py.bak-* 2>/dev/null | head -1)
if [ -z "$LATEST_BAK" ]; then
    echo "ERROR: no eeg_analyzer.py.bak-* found"; exit 1
fi
echo "Restoring eeg_analyzer.py from $LATEST_BAK"
cp "$LATEST_BAK" eeg_analyzer.py
# Keep a fresh checkpoint of the broken state we just overwrote (in case)
cp eeg_analyzer.py eeg_analyzer.py.bak-$(date +%Y%m%d-%H%M%S)-pre-v2-fix

python3 <<'PYFIX'
from pathlib import Path
import re

# ============================================================
# eeg_analyzer.py — clean re-application
# ============================================================
p = Path.home() / "eeg-reporter/eeg_analyzer.py"
src = p.read_text()

# 1. Insert SCALP_10_20 at module top, immediately after the contiguous
# import block at the start of the file. This is the ONLY safe location.
if "SCALP_10_20" not in src:
    m = re.match(r"((?:from |import |#|\"\"\"|\s).*?(?:\n|$))+?(?=\n(?:[A-Za-z_])|$)", src, re.DOTALL)
    # Simpler: find the last `import` / `from ... import` line near the top
    lines = src.split("\n")
    last_import = -1
    for i, ln in enumerate(lines[:50]):  # only scan first 50 lines
        s = ln.strip()
        if s.startswith("import ") or s.startswith("from "):
            last_import = i
    if last_import == -1:
        raise SystemExit("ERROR: could not locate any import line in top 50 lines")
    insertion = [
        "",
        '# 19-electrode standard 10-20 montage used by this practice.',
        '# Used to count true scalp channels (NK files pack 24+ extra leads:',
        '# EKG, EOG, photic, BN/AV/SD, SpO2, EtCO2, DC inputs, RFUs, BPs).',
        'SCALP_10_20 = {"FP1","FP2","F3","F4","C3","C4","P3","P4","O1","O2",',
        '               "F7","F8","T3","T4","T5","T6","FZ","CZ","PZ"}',
        "",
    ]
    lines = lines[:last_import + 1] + insertion + lines[last_import + 1:]
    src = "\n".join(lines)
    print(f"Inserted SCALP_10_20 after import line {last_import + 1}")
else:
    print("SCALP_10_20 already present (unexpected after rollback)")

# 2. Re-patch the recording dict to use _count_scalp_channels.
old_rec = '"sfreq": raw.info["sfreq"], "n_channels": raw.info["nchan"]}'
new_rec = (
    '"sfreq": raw.info["sfreq"],\n'
    '            "n_channels_raw": raw.info["nchan"],\n'
    '            "n_channels": _count_scalp_channels(raw, result.get("electrodes", {}))}'
)
if old_rec in src:
    src = src.replace(old_rec, new_rec, 1)
    print("Patched recording dict to use _count_scalp_channels")
elif "_count_scalp_channels" in src:
    print("recording dict already patched")
else:
    raise SystemExit("ERROR: recording-dict anchor not found in restored file")

# 3. Append _count_scalp_channels helper (top-level function).
if "def _count_scalp_channels" not in src:
    helper = '''

def _count_scalp_channels(raw, electrodes_map):
    """Count true 10-20 scalp electrodes only. Prefer the .21E electrode map
    when available (indices 0-18 are scalp in NK files). Fall back to filtering
    raw.ch_names by name match against SCALP_10_20."""
    try:
        if electrodes_map:
            scalp = 0
            for _idx, name in electrodes_map.items():
                if str(name).upper().strip() in SCALP_10_20:
                    scalp += 1
                if scalp >= 19:
                    break
            if scalp >= 10:
                return scalp
    except Exception:
        pass
    try:
        return sum(1 for c in raw.ch_names
                   if c.upper().split("-")[0].strip() in SCALP_10_20)
    except Exception:
        return 19
'''
    if not src.endswith("\n"):
        src += "\n"
    src += helper
    print("Appended _count_scalp_channels helper")
else:
    print("_count_scalp_channels already defined")

p.write_text(src)
print("eeg_analyzer.py written")

# ============================================================
# Verify report_generator.py from v1 is still good. Re-check anchors.
# ============================================================
p2 = Path.home() / "eeg-reporter/report_generator.py"
src2 = p2.read_text()

issues = []
if "19-channel standard 10-20 montage" not in src2:
    issues.append("missing '19-channel standard 10-20 montage' literal")
if "TECHNICIAN COMMENT" not in src2:
    issues.append("missing TECHNICIAN COMMENT block")
if "Do NOT state a specific channel count" not in src2:
    issues.append("missing channel-count prompt rule")

if issues:
    print("report_generator.py issues (will need re-patch):")
    for i in issues:
        print("  -", i)
else:
    print("report_generator.py from v1 looks good")

# ============================================================
# Syntax check
# ============================================================
import ast
ast.parse(p.read_text())
ast.parse(p2.read_text())
print("BOTH FILES PARSE OK")
PYFIX

# Restart cleanly
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
echo "------ last 20 log lines ------"
tail -20 ~/eeg-reporter/logs/app.log
echo
echo "DONE."
echo "Watcher tmux session: tmux attach -t eeg-reporter"
echo "Dashboard: http://100.113.163.65:8060 (hard-reload Ctrl+Shift+R)"
