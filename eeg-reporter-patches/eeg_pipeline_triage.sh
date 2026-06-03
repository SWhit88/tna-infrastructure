#!/usr/bin/env bash
# eeg_pipeline_triage.sh
# Find where the EEG pipeline broke between 2026-06-01 and today.
# Checks each hop in order: NK Windows -> DS916+ share -> DS918+ replica -> P340 watcher.
# Read-only. Safe to run any time.

set -uo pipefail
echo "=========================================="
echo " EEG Pipeline Triage  $(date)"
echo "=========================================="

# -------- HOP 4: P340 watcher (closest to us, easiest) --------
echo
echo "----- HOP 4: P340 watcher state -----"

if pgrep -f 'python.*app.py' >/dev/null; then
  echo "✓ app.py running (PID: $(pgrep -f 'python.*app.py' | tr '\n' ' '))"
else
  echo "✗ app.py NOT running"
fi
if pgrep -f 'python.*main.py' >/dev/null; then
  echo "✓ main.py (watcher) running (PID: $(pgrep -f 'python.*main.py' | tr '\n' ' '))"
elif pgrep -f 'python.*watcher.py' >/dev/null; then
  echo "✓ watcher.py running directly"
else
  echo "? main.py / watcher.py status unclear - checking app.log activity"
fi

echo
echo "Last 10 lines of app.log:"
tail -n 10 ~/eeg-reporter/logs/app.log 2>/dev/null || echo "  (log not found)"
echo
echo "Most recent log activity timestamp:"
ls -la ~/eeg-reporter/logs/app.log 2>/dev/null | awk '{print $6,$7,$8}'

# -------- HOP 2 & 3: NAS mounts visible from P340 --------
echo
echo "----- HOP 2/3: NAS mounts on P340 -----"

for mp in /mnt/nas916/EEGOfficeData /mnt/nas918/ai-pipeline; do
  if mountpoint -q "$mp" 2>/dev/null; then
    echo "✓ $mp is mounted"
  else
    echo "✗ $mp NOT mounted"
  fi
done

echo
echo "DS916+ eeg-incoming contents (newest 20, last 14 days):"
ls -lat /mnt/nas916/EEGOfficeData/eeg-incoming 2>/dev/null | head -22 || echo "  (cannot list - mount may be down)"

echo
echo "Files modified on DS916+ since 2026-06-01:"
find /mnt/nas916/EEGOfficeData/eeg-incoming -type f -newermt 2026-06-01 2>/dev/null | head -20

echo
echo "DS918+ ai-pipeline/eeg-incoming contents (newest 10):"
ls -lat /mnt/nas918/ai-pipeline/eeg-incoming 2>/dev/null | head -12 || echo "  (cannot list)"

echo
echo "Files modified on DS918+ since 2026-06-01:"
find /mnt/nas918/ai-pipeline/eeg-incoming -type f -newermt 2026-06-01 2>/dev/null | head -20

# -------- HOP 1: NK Windows reachable? --------
echo
echo "----- HOP 1: NK Windows machine -----"
echo "Tailscale ping to NK (100.120.54.88):"
ping -c 2 -W 2 100.120.54.88 2>&1 | tail -3

# -------- Summary --------
echo
echo "=========================================="
echo " DIAGNOSIS HINTS"
echo "=========================================="
echo "  - If 'Files modified since 2026-06-01' on DS916+ is EMPTY:"
echo "      NK watcher is dead (Hop 1->2 broken). Need to fix NK scheduled task."
echo "  - If DS916+ has new files but DS918+ does not:"
echo "      ShareSync broken (Hop 2->3 broken). Direct DS916+ mount workaround."
echo "  - If DS918+ has new files but P340 watcher didn't process them:"
echo "      P340 watcher process died or app.py crashed. Restart needed."
echo "=========================================="
