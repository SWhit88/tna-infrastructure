#!/usr/bin/env bash
set -euo pipefail
APP=~/eeg-reporter/app.py

echo "=== Existing /pdf route definitions ==="
grep -nE '@server\.route|@app\.server\.route|def pdf|"/pdf' "$APP" | head -20
echo
echo "=== preview-redirect Location component definition ==="
grep -nE 'preview-redirect|dcc\.Location' "$APP" | head -10
echo
echo "=== Buttons block (around lines 295-325) ==="
sed -n '295,330p' "$APP"
echo
echo "=== signed/ directory listing (first 5) ==="
ls ~/eeg-reporter/reports/signed/*.pdf 2>/dev/null | head -5
echo
echo "=== Number of signed reports ==="
ls ~/eeg-reporter/reports/signed/*.json 2>/dev/null | wc -l
