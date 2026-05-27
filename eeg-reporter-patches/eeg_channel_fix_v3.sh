#!/bin/bash
# v3 channel fix — places SCALP_10_20 at exact line 6 of eeg_analyzer.py
# (right after `import numpy as np`). No regex heuristics.
set -e
cd ~/eeg-reporter

# 1. Restore from the known-good .bak
ORIG_BAK="eeg_analyzer.py.bak-20260527-125705"
if [ ! -f "$ORIG_BAK" ]; then
    echo "ERROR: pristine backup $ORIG_BAK is missing"
    exit 1
fi
echo "Restoring eeg_analyzer.py from $ORIG_BAK"
cp "$ORIG_BAK" eeg_analyzer.py
cp eeg_analyzer.py eeg_analyzer.py.bak-$(date +%Y%m%d-%H%M%S)-pre-v3-fix

# 2. Verify the restored file's first 6 lines match what we expect.
expected_line5=$(awk 'NR==5' eeg_analyzer.py)
if [ "$expected_line5" != "import numpy as np" ]; then
    echo "ERROR: line 5 is not 'import numpy as np' — got: '$expected_line5'"
    echo "Aborting — the file structure has changed."
    exit 1
fi
echo "Line-5 sanity check: OK ($expected_line5)"

python3 <<'PYFIX'
from pathlib import Path
import ast

p = Path.home() / "eeg-reporter/eeg_analyzer.py"
lines = p.read_text().split("\n")

# ============================================================
# PATCH 1: Insert SCALP_10_20 + comment immediately after line 5.
# Lines list is 0-indexed; line 5 -> index 4. We insert after index 4.
# ============================================================
if any("SCALP_10_20" in ln for ln in lines):
    print("SCALP_10_20 already present (unexpected after restore)")
else:
    insertion = [
        "",
        "# 19-electrode standard 10-20 montage used by this practice.",
        "# Used to count true scalp channels — NK files pack 24+ extra leads",
        "# (EKG, EOG, photic, BN/AV/SD, SpO2, EtCO2, DC inputs, RFUs, BPs).",
        'SCALP_10_20 = {"FP1","FP2","F3","F4","C3","C4","P3","P4","O1","O2",',
        '               "F7","F8","T3","T4","T5","T6","FZ","CZ","PZ"}',
    ]
    lines = lines[:5] + insertion + lines[5:]
    print(f"Inserted SCALP_10_20 after line 5 (now {len(insertion)} new lines)")

src = "\n".join(lines)

# ============================================================
# PATCH 2: Recording dict — use _count_scalp_channels.
# ============================================================
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
    raise SystemExit("ERROR: recording-dict anchor not found")

# Important caveat: _extract_recording is called BEFORE _parse_21e populates
# result["electrodes"]. So at the time the dict is built, electrodes is still {}.
# Solution: change the order in analyze() so .21E is parsed before _extract_recording,
# OR pass eeg_path into _extract_recording and parse .21E inside it.
# Simplest: re-order analyze() to parse .21E first.
old_order = '''        result["patient"]    = _extract_patient(raw, eeg_path)
        result["recording"]  = _extract_recording(raw)'''
new_order = '''        # Parse .21E first so _extract_recording can count true scalp channels
        result["electrodes"]  = _parse_21e(eeg_path)
        result["patient"]    = _extract_patient(raw, eeg_path)
        result["recording"]  = _extract_recording(raw, result["electrodes"])'''
if old_order in src and "_extract_recording(raw, result[\"electrodes\"])" not in src:
    src = src.replace(old_order, new_order, 1)
    print("Re-ordered analyze() so .21E parses before _extract_recording")
elif '_extract_recording(raw, result["electrodes"])' in src:
    print("analyze() already re-ordered")
else:
    print("WARNING: could not re-order analyze() — falling back to result.get pattern")

# Drop the now-redundant later _parse_21e call.
later_21e = '\n    result["electrodes"]  = _parse_21e(eeg_path)\n'
# We want exactly one call; if the early one is in place, remove the later duplicate.
if '_extract_recording(raw, result["electrodes"])' in src and src.count("_parse_21e(eeg_path)") > 1:
    src = src.replace(later_21e, "\n", 1)
    print("Removed duplicate later _parse_21e call")

# Update _extract_recording signature to accept the electrodes map.
old_sig = "def _extract_recording(raw):"
new_sig = "def _extract_recording(raw, electrodes_map=None):"
if old_sig in src:
    src = src.replace(old_sig, new_sig, 1)
    # And update the call site that doesn't pass electrodes (safety net)
    print("Updated _extract_recording signature to accept electrodes_map")

# Now patch the dict body to use the parameter:
old_call = '"n_channels": _count_scalp_channels(raw, result.get("electrodes", {}))'
new_call = '"n_channels": _count_scalp_channels(raw, electrodes_map or {})'
if old_call in src:
    src = src.replace(old_call, new_call, 1)
    print("Switched n_channels to use electrodes_map parameter")

# ============================================================
# PATCH 3: Append _count_scalp_channels helper at end of file.
# ============================================================
if "def _count_scalp_channels" not in src:
    helper = '''

def _count_scalp_channels(raw, electrodes_map):
    """Count true 10-20 scalp electrodes only. Prefer the .21E map
    (NK indices 0-18 are scalp). Fall back to raw.ch_names name match."""
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

# Final syntax check
ast.parse(p.read_text())
print("eeg_analyzer.py PARSES OK")

# Verify report_generator still good (v1 already patched it)
p2 = Path.home() / "eeg-reporter/report_generator.py"
ast.parse(p2.read_text())
print("report_generator.py PARSES OK")
PYFIX

# Restart cleanly
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
echo "------ last 25 log lines ------"
tail -25 ~/eeg-reporter/logs/app.log
echo
echo "Dashboard: http://100.113.163.65:8060 (hard-reload Ctrl+Shift+R)"
echo
echo "To verify with a re-process:"
echo "  rm -f ~/eeg-reporter/reports/FA00133H.processed"
echo "  rm -f ~/eeg-reporter/reports/FA00133H_*.json"
echo "  rm -f ~/eeg-reporter/reports/FA00133H_*.pdf"
echo "  # then wait ~45 seconds and check ~/eeg-reporter/reports/FA00133H_*.json"
