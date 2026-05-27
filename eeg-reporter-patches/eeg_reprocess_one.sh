#!/bin/bash
# Re-process a single EEG bundle directly through analyzer + report_generator,
# bypassing the watcher. Defaults to FA00133H if no arg given.
set -e
STEM="${1:-FA00133H}"
cd ~/eeg-reporter

# Find the source .EEG bundle for this stem. Check the NAS incoming dir first,
# then the historical archive, then anything reachable.
echo "Searching for bundle ${STEM}.EEG ..."
SRC=""
for candidate in \
    /mnt/nas916-direct/eeg-incoming \
    /mnt/nas916/EEGOfficeData/eeg-incoming \
    /mnt/nas918/ai-pipeline/eeg-incoming \
    /mnt/nas916/EEGOfficeData/eeg-historical \
    /mnt/nas/ai-pipeline/eeg-incoming ; do
    if [ -d "$candidate" ]; then
        hit=$(find "$candidate" -maxdepth 4 -iname "${STEM}.EEG" 2>/dev/null | head -1)
        if [ -n "$hit" ]; then
            SRC="$hit"
            echo "Found: $SRC"
            break
        fi
    fi
done
if [ -z "$SRC" ]; then
    echo "ERROR: could not find ${STEM}.EEG in any mounted location"
    exit 1
fi

# Clear stale outputs for this stem
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
print(f"  recording.n_channels      = {findings.get('recording', {}).get('n_channels')}")
print(f"  recording.n_channels_raw  = {findings.get('recording', {}).get('n_channels_raw')}")
print(f"  electrodes count          = {len(findings.get('electrodes', {}))}")
print(f"  pnt_meta.comment          = {findings.get('pnt_meta', {}).get('comment', '')[:80]}")

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
print("=== clinical_history (snippet) ===")
print((report.get("clinical_history") or "")[:300])
PY

echo
echo "Done. Latest JSON:"
ls -lt ~/eeg-reporter/reports/${STEM}_*.json | head -1
