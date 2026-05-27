#!/bin/bash
# Fix channel-count fabrication + activation-flag drift in EEG narrative.
# - Derive n_channels from .21E scalp electrodes only (not MNE's nchan)
# - Pass tech's Comment field into the LLM prompt so activations aren't invented
# - Add explicit prompt rules against fabricating channel counts or activation flags
set -e
cd ~/eeg-reporter
TS=$(date +%Y%m%d-%H%M%S)
cp eeg_analyzer.py eeg_analyzer.py.bak-$TS
cp report_generator.py report_generator.py.bak-$TS

python3 <<'PYFIX'
from pathlib import Path
import re

# ============================================================
# PATCH A: eeg_analyzer.py — replace raw nchan with scalp-only count
# ============================================================
p = Path.home() / "eeg-reporter/eeg_analyzer.py"
src = p.read_text()

# 1. Add SCALP_10_20 constant near the top (after imports). Idempotent.
if "SCALP_10_20" not in src:
    insert_after = 'EXCLUDE_PREFIX = '
    # Insert just BEFORE the existing EXCLUDE_PREFIX line if it exists; else after imports.
    if insert_after in src:
        # find the start of that line
        idx = src.find(insert_after)
        line_start = src.rfind("\n", 0, idx) + 1
        addition = (
            'SCALP_10_20 = {"FP1","FP2","F3","F4","C3","C4","P3","P4","O1","O2",\n'
            '               "F7","F8","T3","T4","T5","T6","FZ","CZ","PZ"}\n'
        )
        src = src[:line_start] + addition + src[line_start:]
        print("Inserted SCALP_10_20 constant before EXCLUDE_PREFIX")
    else:
        # Fallback: insert after first import block
        m = re.search(r"(^(?:from |import ).*\n)+", src, re.MULTILINE)
        if m:
            cut = m.end()
            addition = (
                '\nSCALP_10_20 = {"FP1","FP2","F3","F4","C3","C4","P3","P4","O1","O2",\n'
                '               "F7","F8","T3","T4","T5","T6","FZ","CZ","PZ"}\n'
            )
            src = src[:cut] + addition + src[cut:]
            print("Inserted SCALP_10_20 constant after imports (fallback)")
        else:
            print("WARNING: could not find a clean spot for SCALP_10_20")
else:
    print("SCALP_10_20 already present, skipping")

# 2. Replace the recording dict line that sets n_channels from MNE's nchan.
# Target line (verbatim from diag):
#   "sfreq": raw.info["sfreq"], "n_channels": raw.info["nchan"]}
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
    print("recording dict already patched, skipping")
else:
    raise SystemExit("ERROR: recording-dict anchor not found; aborting before any write")

# 3. Add the _count_scalp_channels helper if missing.
if "def _count_scalp_channels" not in src:
    helper = '''

def _count_scalp_channels(raw, electrodes_map):
    """Count true 10-20 scalp electrodes only. Prefer the .21E electrode map
    when it exists (indices 0-18 are scalp in NK files). Fall back to filtering
    raw.ch_names by name match against SCALP_10_20."""
    try:
        if electrodes_map:
            scalp = 0
            for _idx, name in electrodes_map.items():
                if str(name).upper().strip() in SCALP_10_20:
                    scalp += 1
                # Stop at 19 — NK puts scalp electrodes first
                if scalp >= 19:
                    break
            if scalp >= 10:  # sanity: at least 10 scalp electrodes recognized
                return scalp
    except Exception:
        pass
    # Fallback: filter raw channel names
    try:
        return sum(1 for c in raw.ch_names
                   if c.upper().split("-")[0].strip() in SCALP_10_20)
    except Exception:
        return 19  # last-resort default for this practice
'''
    # Append at end of file
    if not src.endswith("\n"):
        src += "\n"
    src += helper
    print("Added _count_scalp_channels helper")
else:
    print("_count_scalp_channels already defined, skipping")

p.write_text(src)
print("eeg_analyzer.py patches applied")

# ============================================================
# PATCH B: report_generator.py — pass tech Comment into prompt, fix template
# ============================================================
p2 = Path.home() / "eeg-reporter/report_generator.py"
src2 = p2.read_text()

# B.1 Tighten the prompt rules in the docstring/header.
old_rule_block = "- Duration, channels, sample rate, montage, filters, notch."
new_rule_block = (
    "- Duration, channels, sample rate, montage, filters, notch.\n"
    "- Do NOT state a specific channel count unless one is explicitly provided.\n"
    "  This practice uses a standard 19-channel 10-20 montage. Refer to it as\n"
    '  "19-channel standard 10-20 montage" or simply "standard 10-20 montage".\n'
    "- Use the activation flags from the technician comment EXACTLY as provided.\n"
    '  Do NOT state that any activation was "not performed" or "not recorded"\n'
    "  unless the technician comment explicitly says so."
)
if old_rule_block in src2 and new_rule_block not in src2:
    src2 = src2.replace(old_rule_block, new_rule_block, 1)
    print("Tightened prompt rules block")
elif new_rule_block in src2:
    print("Prompt rules already tightened, skipping")
else:
    print("WARNING: prompt-rules anchor not found exactly; will try fallback below")

# B.2 Fix the hard-templated channel sentence (line 219 region):
# OLD: f"{rec.get('duration_min','?')}-minute digital EEG, {rec.get('n_channels','?')} channels, "
old_sentence = 'f"{rec.get(\'duration_min\',\'?\')}-minute digital EEG, {rec.get(\'n_channels\',\'?\')} channels, "'
new_sentence = 'f"{rec.get(\'duration_min\',\'?\')}-minute digital EEG using a 19-channel standard 10-20 montage, "'
if old_sentence in src2:
    src2 = src2.replace(old_sentence, new_sentence, 1)
    print("Replaced hard-templated channel-count sentence")
elif "19-channel standard 10-20 montage" in src2:
    print("Channel-count sentence already fixed")
else:
    print("WARNING: channel-sentence anchor not found exactly; please check manually")

# B.3 Make sure the technician Comment is exposed inside the prompt context.
# Look for the prompt assembly. We'll add a "TECHNICIAN COMMENT" block if not present.
if 'TECHNICIAN COMMENT' not in src2:
    # Find the existing rec-summary line emitted in _build_prompt (around line 169):
    # "Channels: {rec.get('n_channels','?')} | Sample rate: {rec.get('sfreq','?')} Hz"
    rec_line = "Channels: {rec.get('n_channels','?')} | Sample rate: {rec.get('sfreq','?')} Hz"
    if rec_line in src2:
        # Insert a tech-comment line right after. We pull from the patient dict.
        # Locate the f-string this is in and insert a new line before its closing.
        # Simplest: do a textual insert immediately after the matched line.
        new_rec_line = (
            "Channels: 19 (standard 10-20 montage) | Sample rate: {rec.get('sfreq','?')} Hz\n"
            "TECHNICIAN COMMENT (use activation flags exactly as written, do not invent):\n"
            "{(f.get('patient',{}) or {}).get('comment','') or 'No technician comment recorded.'}"
        )
        src2 = src2.replace(rec_line, new_rec_line, 1)
        print("Added TECHNICIAN COMMENT block to prompt")
    else:
        print("WARNING: rec_line anchor not found — please add TECHNICIAN COMMENT block manually")
else:
    print("TECHNICIAN COMMENT already in prompt, skipping")

p2.write_text(src2)
print("report_generator.py patches applied")

# ============================================================
# Syntax check
# ============================================================
import ast
ast.parse(Path.home().joinpath("eeg-reporter/eeg_analyzer.py").read_text())
ast.parse(Path.home().joinpath("eeg-reporter/report_generator.py").read_text())
print("BOTH FILES PARSE OK")
PYFIX

# Restart Dash dashboard (watcher restart not required — analyzer/report_generator
# are reloaded on each new study)
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
echo "------ last 15 log lines ------"
tail -15 ~/eeg-reporter/logs/app.log
echo
echo "DONE. To verify, force-rebuild FA00133H:"
echo "  rm -f ~/eeg-reporter/reports/FA00133H.processed"
echo "  rm -f ~/eeg-reporter/reports/FA00133H_*.json"
echo "  rm -f ~/eeg-reporter/reports/FA00133H_*.pdf"
echo "  # Watcher will pick it up within ~1 second."
