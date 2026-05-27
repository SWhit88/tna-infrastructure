#!/bin/bash
# v3: No find. Direct path construction and stat. Try common case variants.
set -e
STEM="${1:-FA00133H}"
INCOMING="/mnt/nas916-direct/eeg-incoming"
cd ~/eeg-reporter

# If user passed an absolute path, use it directly
if [[ "$STEM" == /* ]] && [ -f "$STEM" ]; then
    SRC="$STEM"
    STEM=$(basename "$SRC")
    STEM="${STEM%.*}"
    echo "Using absolute path: $SRC (stem=$STEM)"
else
    echo "Looking for ${STEM} in $INCOMING ..."
    SRC=""
    # Try every common extension case for the .EEG file
    for ext in EEG eeg Eeg; do
        cand="$INCOMING/${STEM}.${ext}"
        if [ -f "$cand" ]; then
            SRC="$cand"
            echo "Found: $SRC"
            break
        fi
    done
    if [ -z "$SRC" ]; then
        echo "Not found via direct stat. Listing actual entries for ${STEM}*:"
        timeout 5 ls "$INCOMING/${STEM}"* 2>/dev/null || echo "  (none)"
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
