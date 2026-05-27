#!/usr/bin/env bash
# Show the full traceback for the most recent IndexError, plus the HTTP entries
# that bracket it (so we can tell which callback fired).
set -euo pipefail
LOG=~/eeg-reporter/logs/app.log

echo "=================== Last error block (40 lines around final IndexError) ==================="
# Find last IndexError line number
LAST=$(grep -n "IndexError" "$LOG" | tail -1 | cut -d: -f1)
if [ -n "$LAST" ]; then
  START=$((LAST - 40))
  [ $START -lt 1 ] && START=1
  END=$((LAST + 5))
  sed -n "${START},${END}p" "$LOG"
else
  echo "(no IndexError found)"
fi

echo
echo "=================== Last 5 distinct triggered callbacks (by Outputs string) ==================="
# Grep for callback dispatch lines if any; otherwise show last 10 POST lines
tail -200 "$LOG" | grep -E "(_dash-update-component|Triggered|Output)" | tail -20
