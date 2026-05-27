#!/bin/bash
# v2: Fast direct re-process. Only searches local reports dir + the direct NAS
# mount that we know the watcher uses (no slow find across stale mounts).
set -e
STEM="${1:-FA00133H}"
cd ~/eeg-reporter

echo "Searching for bundle ${STEM}.EEG ..."
# Only search the path the live watcher uses, plus a couple of cheap local dirs.
# Use a 5-second timeout on find so a stale mount cannot wedge us.
SRC=""
for candidate in \
    /mnt/nas916-direct/eeg-incoming \
    ~/eeg-reporter/incoming ; do
    if [ -d "$candidate" ]; then
        # -maxdepth 3 + timeout caps work to ~5s even on a slow share
        hit=$(timeout 5 find "$candidate" -maxdepth 3 -iname "${STEM}.EEG" 2>/dev/null | head -1)
        if [ -n "$hit" ]; then
            SRC="$hit"
            echo "Found: $SRC"
            break
        fi
    fi
done

if [ -z "$SRC" ]; then
    echo "Not found in incoming dirs; listing what's in /mnt/nas916-direct/eeg-incoming (top 30 entries):"
    timeout 5 ls /mnt/nas916-direct/eeg-incoming 2>/dev/null | head -30 || echo "  (mount unresponsive)"
    echo
    echo "Hint: run with the full path as arg:"
    echo "  bash /tmp/eeg_re2.sh /full/path/to/${STEM}.EEG"
    # If user passed an absolute path that exists, use it
    if [ -f "$STEM" ]; then
        SRC="$STEM"
        STEM=$(basename "$SRC" .EEG)
        echo "Using path from arg: $SRC (stem=$STEM)"
    else
        exit 1
    fi
fi

# Clear stale outputs
rm -f ~/eeg-reporter/reports/${STEM}.processed
rm -f ~/eeg-reporter/reports/${STEM}_*.json
rm -f ~/eeg-reporter/reports/${STEM}_*.pdf
echo "Cleared stale outputs for ${STEM}"

# Run analyzer + report generator directly
python3 <<PY
import sys, json
from pathlib import Path
sys.path.insert(0, str(Path.home() / "eeg-reporter"))

from eeg_analyzer import analyze
from report_generator import build_report

src = Path("$SRC")
print(f"Analyzing: {src}")
findings = analyze(src)
rec = findings.get("recording", {})
print(f"  recording.n_channels      = {rec.get('n_channels')}")
print(f"  recording.n_channels_raw  = {rec.get('n_channels_raw')}")
print(f"  electrodes count          = {len(findings.get('electrodes', {}))}")
print(f"  pnt_meta.comment          = {findings.get('pnt_meta', {}).get('comment', '')[:120]}")
print()
print("Building report ...")
report = build_report(findings)
out_dir = Path.home() / "eeg-reporter" / "reports"
out_dir.mkdir(parents=True, exist_ok=True)
from datetime import datetime
ts = datetime.now().strftime("%Y%m%d_%H%M%S")
out_json = out_dir / f"${STEM}_{ts}.json"
out_json.write_text(json.dumps({"report": report, "findings": findings}, indent=2, default=str))
print(f"Wrote: {out_json}")
print()
print("=== technical_description ===")
print(report.get("technical_description", "(missing)"))
print()
print("=== clinical_history (first 300 chars) ===")
print((report.get("clinical_history") or "")[:300])
PY

echo
echo "Done. Latest JSON:"
ls -lt ~/eeg-reporter/reports/${STEM}_*.json | head -1
