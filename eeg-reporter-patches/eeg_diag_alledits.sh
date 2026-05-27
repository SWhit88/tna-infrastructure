#!/usr/bin/env bash
set -euo pipefail
APP=~/eeg-reporter/app.py
echo "=== ALL_EDITS and HEADER_FIELDS definitions ==="
grep -nE "^(ALL_EDITS|HEADER_FIELDS|BODY_FIELDS|EDITABLE)" "$APP"
echo
echo "=== context lines for ALL_EDITS (50 lines around first hit) ==="
LN=$(grep -n "^ALL_EDITS" "$APP" | head -1 | cut -d: -f1)
if [ -n "$LN" ]; then
  START=$((LN - 5)); END=$((LN + 20))
  sed -n "${START},${END}p" "$APP"
fi
echo
echo "=== Every edit-* id that show_report actually creates ==="
grep -oE 'id=f?"edit-[a-z_]+"' "$APP" | sort -u
echo
echo "=== Every name passed to _input_row / _textarea_row ==="
grep -nE '_input_row\(|_textarea_row\(' "$APP" | head -40
