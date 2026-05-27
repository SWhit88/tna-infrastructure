#!/bin/bash
# Resume-aware batch reprocess. Skips stems whose latest report JSON timestamp
# is AFTER the v3 fix landed (today at 14:22 EDT). Runs detached via nohup
# so you can close your SSH session / laptop.
#
# Usage:
#   bash eeg_batch_reprocess_resume.sh           # foreground (Ctrl+C to abort cleanly)
#   bash eeg_batch_reprocess_resume.sh --detach  # detached, log to logs/, safe to close shell
set -e
INCOMING="/mnt/nas916-direct/eeg-incoming"
REPORTS=~/eeg-reporter/reports
# Anything timestamped at or after this is considered "already fixed"
CUTOFF="20260527_142200"   # today, 14:22:00 EDT — when v3 sig fix landed
LOGFILE=~/eeg-reporter/logs/batch_resume_$(date +%Y%m%d_%H%M%S).log

cd ~/eeg-reporter

# Build the worker as a standalone python file so nohup can exec it cleanly.
cat > /tmp/eeg_batch_worker.py <<PY
import sys, json, time, re
from pathlib import Path
from datetime import datetime
sys.path.insert(0, str(Path.home() / "eeg-reporter"))

from eeg_analyzer import analyze
from report_generator import generate

INCOMING = Path("$INCOMING")
REPORTS  = Path("$REPORTS")
CUTOFF   = "$CUTOFF"

# Collect every stem that has at least one report dated 2026-05-27
all_today = sorted({p.name.split("_")[0]
                    for p in REPORTS.glob("FA*_20260527_*.json")})

# Decide which stems still need reprocessing
def latest_ts(stem):
    files = list(REPORTS.glob(f"{stem}_20260527_*.json"))
    if not files:
        return ""
    return max(re.search(r"_(\d{8}_\d{6})\.json", f.name).group(1) for f in files)

todo = [s for s in all_today if latest_ts(s) < CUTOFF]
done_already = len(all_today) - len(todo)

print(f"Total today-dated stems: {len(all_today)}")
print(f"Already reprocessed (>= {CUTOFF}): {done_already}")
print(f"Still to do: {len(todo)}")
print()

ok = skip = fail = 0
t_start = time.time()
for i, stem in enumerate(todo, 1):
    src = None
    for ext in ("EEG", "eeg"):
        cand = INCOMING / f"{stem}.{ext}"
        if cand.exists():
            src = cand; break
    if src is None:
        print(f"[{i}/{len(todo)}] {stem}: SKIP (source missing)", flush=True)
        skip += 1
        continue
    try:
        t0 = time.time()
        print(f"[{i}/{len(todo)}] {stem}: analyzing ...", flush=True)
        for old in REPORTS.glob(f"{stem}_20260527_*.json"):
            if re.search(r"_(\d{8}_\d{6})\.json", old.name).group(1) < CUTOFF:
                old.unlink()
        for old in REPORTS.glob(f"{stem}_20260527_*.pdf"):
            old.unlink()
        proc = REPORTS / f"{stem}.processed"
        if proc.exists(): proc.unlink()

        findings = analyze(src)
        rec = findings.get("recording", {})
        n_ch = rec.get("n_channels")
        report = generate(findings)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_json = REPORTS / f"{stem}_{ts}.json"
        out_json.write_text(json.dumps({"report": report, "findings": findings}, indent=2, default=str))
        proc.write_text("reprocessed")
        td = (report.get("technical_description") or "")[:80]
        elapsed = time.time() - t0
        print(f"   OK n_channels={n_ch} ({elapsed:.0f}s) — {td}", flush=True)
        ok += 1
    except Exception as exc:
        print(f"   FAIL: {exc}", flush=True)
        fail += 1

total_elapsed = time.time() - t_start
print()
print(f"Summary: ok={ok} skipped={skip} failed={fail} of {len(todo)}")
print(f"Total elapsed: {total_elapsed/60:.1f} min")
PY

if [ "${1:-}" = "--detach" ]; then
    echo "Launching detached. Logfile: $LOGFILE"
    nohup python3 /tmp/eeg_batch_worker.py > "$LOGFILE" 2>&1 &
    BPID=$!
    disown
    echo "PID: $BPID — safe to close shell."
    echo "Watch with:  tail -f $LOGFILE"
    echo "Kill with:   kill $BPID"
else
    python3 /tmp/eeg_batch_worker.py | tee "$LOGFILE"
fi
