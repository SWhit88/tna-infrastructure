#!/bin/bash
# v4: Uses the correct function name `generate` from report_generator.
set -e
STEM="${1:-FA0011U9}"
INCOMING="/mnt/nas916-direct/eeg-incoming"
cd ~/eeg-reporter

if [[ "$STEM" == /* ]] && [ -f "$STEM" ]; then
    SRC="$STEM"
    STEM=$(basename "$SRC")
    STEM="${STEM%.*}"
    echo "Using absolute path: $SRC (stem=$STEM)"
else
    echo "Looking for ${STEM} in $INCOMING ..."
    SRC=""
    for ext in EEG eeg Eeg; do
        cand="$INCOMING/${STEM}.${ext}"
        if [ -f "$cand" ]; then
            SRC="$cand"
            echo "Found: $SRC"
            break
        fi
    done
    if [ -z "$SRC" ]; then
        echo "Not found via direct stat."
        timeout 5 ls "$INCOMING/${STEM}"* 2>/dev/null || echo "  (none)"
        exit 1
    fi
fi

rm -f ~/eeg-reporter/reports/${STEM}.processed
rm -f ~/eeg-reporter/reports/${STEM}_*.json
rm -f ~/eeg-reporter/reports/${STEM}_*.pdf
echo "Cleared stale outputs for ${STEM}"

python3 <<PY
import sys, json
from pathlib import Path
sys.path.insert(0, str(Path.home() / "eeg-reporter"))

from eeg_analyzer import analyze
from report_generator import generate

src = Path("$SRC")
print(f"Analyzing: {src}")
findings = analyze(src)
rec = findings.get("recording", {})
print(f"  recording.n_channels      = {rec.get('n_channels')}")
print(f"  recording.n_channels_raw  = {rec.get('n_channels_raw')}")
print(f"  electrodes count          = {len(findings.get('electrodes', {}))}")
print(f"  pnt_meta.comment          = {findings.get('pnt_meta', {}).get('comment', '')[:140]}")
print()
print("Generating report (calls Ollama — may take 20-60s) ...")
report = generate(findings)

out_dir = Path.home() / "eeg-reporter" / "reports"
out_dir.mkdir(parents=True, exist_ok=True)
from datetime import datetime
ts = datetime.now().strftime("%Y%m%d_%H%M%S")
out_json = out_dir / f"${STEM}_{ts}.json"
out_json.write_text(json.dumps({"report": report, "findings": findings}, indent=2, default=str))
print(f"Wrote: {out_json}")
print()

# Print whatever report shape we got — keys vary
print("=== report.keys() ===")
print(list(report.keys()) if isinstance(report, dict) else type(report))
print()

def get(d, *keys):
    for k in keys:
        if isinstance(d, dict) and k in d:
            return d[k]
    return None

td = get(report, "technical_description", "technical")
if td:
    print("=== technical_description ===")
    print(td)
    print()

ch = get(report, "clinical_history", "history")
if ch:
    print("=== clinical_history (first 300 chars) ===")
    print(str(ch)[:300])
PY

echo
echo "Done. Latest JSON:"
ls -lt ~/eeg-reporter/reports/${STEM}_*.json | head -1
