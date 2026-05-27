#!/bin/bash
# Re-process every stem that has a report dated 2026-05-27. Skips stems whose
# source .EEG file is missing from /mnt/nas916-direct/eeg-incoming.
set -e
INCOMING="/mnt/nas916-direct/eeg-incoming"
REPORTS=~/eeg-reporter/reports
LOGFILE=~/eeg-reporter/logs/batch_reprocess_$(date +%Y%m%d_%H%M%S).log

cd ~/eeg-reporter

echo "Finding stems with reports from today (2026-05-27) ..."
STEMS=$(ls -1 $REPORTS/*_20260527_*.json 2>/dev/null \
    | sed -E 's|.*/(FA[A-Z0-9]{6})_.*|\1|' \
    | sort -u)

if [ -z "$STEMS" ]; then
    echo "No today-dated reports found. Nothing to do."
    exit 0
fi

N=$(echo "$STEMS" | wc -l)
echo "Found $N unique stems to reprocess:"
echo "$STEMS" | head -20
[ $N -gt 20 ] && echo "  ... and $((N-20)) more"
echo
echo "Logfile: $LOGFILE"
echo "Starting in 3 seconds — Ctrl-C now to abort."
sleep 3

python3 - <<PY 2>&1 | tee $LOGFILE
import sys, json, time
from pathlib import Path
from datetime import datetime
sys.path.insert(0, str(Path.home() / "eeg-reporter"))

from eeg_analyzer import analyze
from report_generator import generate

stems = """$STEMS""".strip().split()
incoming = Path("$INCOMING")
reports = Path("$REPORTS")

ok, skip, fail = 0, 0, 0
total = len(stems)

for i, stem in enumerate(stems, 1):
    src = None
    for ext in ("EEG", "eeg"):
        cand = incoming / f"{stem}.{ext}"
        if cand.exists():
            src = cand
            break
    if src is None:
        print(f"[{i}/{total}] {stem}: SKIP (source .EEG not found)")
        skip += 1
        continue

    try:
        t0 = time.time()
        print(f"[{i}/{total}] {stem}: analyzing ...", flush=True)
        # Wipe stale outputs for this stem
        for old in reports.glob(f"{stem}_*.json"):
            old.unlink()
        for old in reports.glob(f"{stem}_*.pdf"):
            old.unlink()
        proc = reports / f"{stem}.processed"
        if proc.exists():
            proc.unlink()

        findings = analyze(src)
        rec = findings.get("recording", {})
        n_ch = rec.get("n_channels")
        report = generate(findings)

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_json = reports / f"{stem}_{ts}.json"
        out_json.write_text(json.dumps({"report": report, "findings": findings}, indent=2, default=str))
        proc.write_text("reprocessed")
        elapsed = time.time() - t0
        td = report.get("technical_description", "")[:80]
        print(f"   OK n_channels={n_ch} ({elapsed:.0f}s) — {td}")
        ok += 1
    except Exception as exc:
        print(f"   FAIL: {exc}")
        fail += 1

print()
print(f"Summary: ok={ok}  skipped={skip}  failed={fail}  total={total}")
PY

echo
echo "Done. Logfile: $LOGFILE"
