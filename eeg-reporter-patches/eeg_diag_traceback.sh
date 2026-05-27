#!/bin/bash
# Show the full traceback of the IndexError so we can identify which callback
# is throwing on every button click.
set -e
cd ~/eeg-reporter

echo "=========== Full traceback context around 'IndexError' ==========="
grep -n -B1 -A30 "IndexError: list index out of range" logs/app.log | tail -80
echo

echo "=========== Recent 500s with stem/n_clicks-like context ==========="
grep -n -B1 -A2 "500 -" logs/app.log | tail -30
echo

echo "=========== Number of callbacks decorated in app.py ==========="
grep -cE "^@app\.callback" app.py
echo

echo "=========== Lines containing 'sorted_reports\\|reports\\[' or list-indexing patterns ==========="
grep -nE 'sorted_reports\[|reports\[|matches\[' app.py | head -20
echo

echo "=========== Layout components with id attribute ==========="
grep -nE 'id="[a-z-]+"' app.py | sed -E 's/.*id="([^"]+)".*/\1/' | sort -u | head -40
