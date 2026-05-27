#!/usr/bin/env bash
# Dump body of show_report and definition of _SAVE_STATES + editable HEADER_FIELDS,
# plus look for places where flat_data indexing could break.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

echo "=================== _SAVE_STATES definition ==================="
grep -n "_SAVE_STATES" "$APP" | head -20
echo
echo "=================== HEADER_FIELDS / editable-fields constants ==================="
grep -nE "^(HEADER_FIELDS|EDITABLE_FIELDS|_EDITABLE|SAVE_STATES|_SAVE_STATES)\b" "$APP" | head -20
echo
echo "=================== show_report full body (lines 195-260) ==================="
sed -n '195,260p' "$APP"
echo
echo "=================== save_draft full body (lines 365-430) ==================="
sed -n '365,430p' "$APP"
echo
echo "=================== do_sign full body (lines 438-495) ==================="
sed -n '438,495p' "$APP"
echo
echo "=================== Editor status / editable-field IDs in layout ==================="
grep -nE 'id=("editor-|"edit-|"hdr-)' "$APP" | head -30
