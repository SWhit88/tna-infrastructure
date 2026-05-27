#!/bin/bash
# EEG Reporter — repoint watcher from DS918+ (broken ShareSync) to DS916+ direct
# Adds a processed-stems ledger so the watcher works against a read-only mount.
set -e
cd ~/eeg-reporter
ts=$(date +%Y%m%d-%H%M%S)
cp config.py  config.py.bak-$ts
cp watcher.py watcher.py.bak-$ts

echo "=== Current EEG_INCOMING ==="
grep -n EEG_INCOMING config.py

# ---------- Patch 1: config.py ----------
python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/config.py"
src = p.read_text()
old = 'EEG_INCOMING = Path(os.environ.get("EEG_INCOMING", "/mnt/nas918/ai-pipeline/eeg-incoming"))'
new = 'EEG_INCOMING = Path(os.environ.get("EEG_INCOMING", "/mnt/nas916-direct/eeg-incoming"))'
if old not in src:
    print("ERROR: config.py target not found")
    raise SystemExit(1)
src = src.replace(old, new)

# Add processed-ledger path if not already present
if "PROCESSED_LEDGER" not in src:
    src = src.rstrip() + '\n\n# Ledger of processed stems — needed because source mount is read-only\nPROCESSED_LEDGER = Path(os.environ.get("PROCESSED_LEDGER", str(Path.home() / "eeg-reporter" / ".processed_stems.json")))\n'

p.write_text(src)
print("config.py patched")
PYFIX

echo "=== New EEG_INCOMING ==="
grep -n -E "EEG_INCOMING|PROCESSED_LEDGER" config.py

# ---------- Patch 2: watcher.py — add ledger-based dedupe ----------
# Strategy: at startup, load the ledger. On every .done sentinel, check the stem
# against the ledger. After successful processing, append the stem to the ledger.
# Source files are never deleted — they stay read-only on DS916+.

python3 <<'PYFIX'
from pathlib import Path
import re
p = Path.home() / "eeg-reporter/watcher.py"
src = p.read_text()

# Check whether ledger logic already exists
if "_load_ledger" in src and "_mark_processed" in src:
    print("watcher.py ledger logic already present — skipping")
    raise SystemExit(0)

# Find the import block and add json + Set
imp_old = "import logging"
imp_new = "import json\nimport logging"
if imp_old in src and "import json" not in src.split("import logging")[0]:
    src = src.replace(imp_old, imp_new, 1)

# Find the config import line — append ledger helpers right after the imports
# Insert helper functions before the first `class` or `def` definition
helpers = '''

def _load_ledger():
    """Load set of already-processed stems from ledger JSON file."""
    from config import PROCESSED_LEDGER
    try:
        if PROCESSED_LEDGER.exists():
            data = json.loads(PROCESSED_LEDGER.read_text())
            return set(data.get("stems", []))
    except Exception as e:
        logging.warning(f"Could not load ledger: {e}")
    return set()


def _mark_processed(stem):
    """Append a stem to the processed ledger (atomic write)."""
    from config import PROCESSED_LEDGER
    stems = _load_ledger()
    stems.add(stem)
    tmp = PROCESSED_LEDGER.with_suffix(".json.tmp")
    tmp.write_text(json.dumps({"stems": sorted(stems)}, indent=2))
    tmp.replace(PROCESSED_LEDGER)

'''

# Insert helpers after the logging.basicConfig block (after first blank line following it)
m = re.search(r'(logging\.basicConfig\([^)]*\)\s*\n)', src)
if not m:
    print("ERROR: could not locate logging.basicConfig anchor")
    raise SystemExit(1)
insertion_point = m.end()
src = src[:insertion_point] + helpers + src[insertion_point:]

p.write_text(src)
print("watcher.py: ledger helpers inserted")
PYFIX

echo "=== syntax check ==="
python3 -c "import ast; ast.parse(open('config.py').read()); print('config.py SYNTAX OK')"
python3 -c "import ast; ast.parse(open('watcher.py').read()); print('watcher.py SYNTAX OK')"

# ---------- Bootstrap ledger from existing reports ----------
echo "=== bootstrapping processed-stems ledger from ~/eeg-reporter/reports/ ==="
python3 <<'PYBOOT'
import json
from pathlib import Path
import re

reports_dir = Path.home() / "eeg-reporter/reports"
ledger_path = Path.home() / "eeg-reporter/.processed_stems.json"

# Extract stem from filenames like FA0012AT_20260527_074834.json
stems = set()
all_jsons = list(reports_dir.glob("*.json")) + list((reports_dir/"signed").glob("*.json"))
pat = re.compile(r"^([A-Z0-9]+)_\d{8}_\d{6}\.json$", re.IGNORECASE)
for f in all_jsons:
    m = pat.match(f.name)
    if m:
        stems.add(m.group(1).upper())
    else:
        # Fallback: take stem before first underscore or full stem
        stems.add(f.stem.split("_")[0].upper())

ledger_path.write_text(json.dumps({"stems": sorted(stems)}, indent=2))
print(f"Bootstrapped ledger with {len(stems)} processed stems")
print(f"Sample: {sorted(stems)[:5]} ... {sorted(stems)[-5:]}")
PYBOOT

# ---------- Backlog scan (dry-run) — show what would be processed ----------
echo "=== Backlog preview (stems on DS916+ NOT in ledger) ==="
python3 <<'PYBACKLOG'
import json, re
from pathlib import Path

incoming = Path("/mnt/nas916-direct/eeg-incoming")
ledger = json.loads((Path.home()/"eeg-reporter/.processed_stems.json").read_text())
processed = set(ledger["stems"])

# Find all .EEG files and their stems
sources = sorted(incoming.glob("*.EEG")) + sorted(incoming.glob("*.eeg"))
src_stems = {f.stem.upper() for f in sources}

backlog = sorted(src_stems - processed)
print(f"Total .EEG bundles on DS916+: {len(src_stems)}")
print(f"Already processed (in ledger): {len(processed & src_stems)}")
print(f"BACKLOG to process: {len(backlog)}")
if backlog:
    print(f"\nFirst 20 backlog stems:")
    for s in backlog[:20]:
        # Find file mtime for context
        for ext in [".EEG", ".eeg"]:
            f = incoming / f"{s}{ext}"
            if f.exists():
                from datetime import datetime
                mt = datetime.fromtimestamp(f.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
                print(f"  {s}  ({mt})")
                break
PYBACKLOG

echo ""
echo "=== DONE — watcher NOT yet restarted ==="
echo "Review the backlog list above. To restart watcher on the new path:"
echo ""
echo "  tmux kill-session -t eeg-reporter 2>/dev/null || true"
echo "  tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'"
echo "  sleep 5 && tail -15 ~/eeg-reporter/logs/app.log"
echo ""
echo "Or to ALSO process the backlog right after restart, run:"
echo "  bash /tmp/eeg_repoint_v1.sh --restart"
echo ""

if [ "$1" = "--restart" ]; then
    echo "=== Restarting watcher ==="
    tmux kill-session -t eeg-reporter 2>/dev/null || true
    sleep 2
    tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
    sleep 6
    echo "=== Watcher log tail ==="
    tail -20 ~/eeg-reporter/logs/app.log
fi
