#!/bin/bash
# EEG Reporter — v2: backfill .processed markers + verify watcher state
# v1 already flipped EEG_INCOMING to /mnt/nas916-direct/eeg-incoming. Good.
# v2: just bootstrap the .processed markers for any stems that have a JSON
# report but no marker. Then preview the real backlog. Then optionally restart.
set -e
cd ~/eeg-reporter

echo "=== Confirm config.py is on DS916+ direct ==="
grep -n "EEG_INCOMING" config.py | head -3

echo ""
echo "=== Bootstrap .processed markers from existing reports ==="
python3 <<'PYBOOT'
import re
from pathlib import Path

reports_dir = Path.home() / "eeg-reporter/reports"

# Find every stem we already have a JSON report for
stems = set()
all_jsons = list(reports_dir.glob("*.json")) + list((reports_dir/"signed").glob("*.json"))
pat = re.compile(r"^(FA[0-9A-Z]{6})(?:_\d{8}_\d{6})?\.json$", re.IGNORECASE)
for f in all_jsons:
    m = pat.match(f.name)
    if m:
        stems.add(m.group(1).upper())

# Check which stems lack a .processed marker
existing_markers = {p.stem.upper() for p in reports_dir.glob("*.processed")}
missing = stems - existing_markers
print(f"Reports with FA-style stem: {len(stems)}")
print(f"Existing .processed markers: {len(existing_markers)}")
print(f"Missing markers to create:   {len(missing)}")

# Create missing markers
created = 0
for stem in sorted(missing):
    marker = reports_dir / f"{stem}.processed"
    if not marker.exists():
        marker.touch()
        created += 1

print(f"Created {created} .processed marker files")
PYBOOT

echo ""
echo "=== Backlog preview: stems on DS916+ that have NO .processed marker ==="
python3 <<'PYBACKLOG'
from pathlib import Path
from datetime import datetime

incoming = Path("/mnt/nas916-direct/eeg-incoming")
reports_dir = Path.home() / "eeg-reporter/reports"

# All stems on DS916+ (from .EEG files)
src_eegs = list(incoming.glob("*.EEG")) + list(incoming.glob("*.eeg"))
src_stems = {f.stem.upper(): f for f in src_eegs}

# Stems already processed
markers = {p.stem.upper() for p in reports_dir.glob("*.processed")}

backlog = sorted(set(src_stems.keys()) - markers)
print(f"Total .EEG bundles on DS916+: {len(src_stems)}")
print(f"Already-processed markers:    {len(markers & set(src_stems.keys()))}")
print(f"BACKLOG to process:           {len(backlog)}")
print()
if backlog:
    print("All backlog stems with mtime (chronological):")
    items = []
    for stem in backlog:
        f = src_stems[stem]
        mt = f.stat().st_mtime
        items.append((mt, stem, datetime.fromtimestamp(mt).strftime("%Y-%m-%d %H:%M")))
    for mt, stem, ts in sorted(items):
        print(f"  {ts}  {stem}")
PYBACKLOG

echo ""
echo "=== Confirm watcher.py was NOT modified (sanity) ==="
md5sum watcher.py
echo ""
echo "=== Last-modified time on watcher.py and config.py ==="
ls -l watcher.py config.py | awk '{print $6, $7, $8, $NF}'

echo ""
echo "=== Confirm sentinel files for backlog stems exist ==="
python3 <<'PYSENT'
from pathlib import Path
incoming = Path("/mnt/nas916-direct/eeg-incoming")
reports_dir = Path.home() / "eeg-reporter/reports"
src_stems = {f.stem.upper() for f in incoming.glob("*.EEG")}
markers = {p.stem.upper() for p in reports_dir.glob("*.processed")}
backlog = src_stems - markers
done_files = {p.stem.upper() for p in incoming.glob("*.done")}
without_done = backlog - done_files
print(f"Backlog stems WITH .done sentinel:    {len(backlog & done_files)}")
print(f"Backlog stems WITHOUT .done sentinel: {len(without_done)}")
if without_done:
    print("  (these will NOT be picked up by the watcher)")
    for s in sorted(without_done)[:10]:
        print(f"    {s}")
PYSENT

echo ""
echo "=== DONE ==="
echo ""
echo "If backlog looks sane, restart the watcher:"
echo ""
echo "  tmux kill-session -t eeg-reporter 2>/dev/null || true"
echo "  tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'"
echo "  sleep 8 && tail -20 ~/eeg-reporter/logs/app.log"
echo ""
echo "Or run with --restart to do it automatically:"
echo "  bash /tmp/eeg_repoint_v2.sh --restart"

if [ "$1" = "--restart" ]; then
    echo ""
    echo "=== Restarting watcher ==="
    tmux kill-session -t eeg-reporter 2>/dev/null || true
    sleep 2
    tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
    sleep 8
    echo "=== Last 25 lines of app.log ==="
    tail -25 ~/eeg-reporter/logs/app.log
fi
