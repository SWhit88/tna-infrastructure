#!/usr/bin/env bash
# Quick diagnostic — show current state of fig.update_layout in app.py
# and the chart-related dcc.Graph call. No changes made.
set -euo pipefail
APP=~/eeg-reporter/app.py

echo "=========================================="
echo "1. Lines containing 'fig.update_layout' and 50 lines after each:"
echo "=========================================="
grep -n "fig.update_layout" "$APP" | while IFS=: read -r ln rest; do
    echo "--- Match at line $ln ---"
    sed -n "${ln},$((ln+30))p" "$APP"
    echo ""
done

echo "=========================================="
echo "2. Lines containing 'dcc.Graph':"
echo "=========================================="
grep -n "dcc.Graph" "$APP" | head -10

echo "=========================================="
echo "3. Lines around dcc.Graph:"
echo "=========================================="
grep -n "dcc.Graph" "$APP" | head -5 | while IFS=: read -r ln rest; do
    echo "--- Match at line $ln ---"
    sed -n "$((ln-2)),$((ln+15))p" "$APP"
    echo ""
done

echo "=========================================="
echo "4. Lines containing 'fig =' or 'fig=' (figure construction):"
echo "=========================================="
grep -n "fig\s*=\s*" "$APP" | head -10

echo "=========================================="
echo "5. Lines containing 'go.Bar' or 'px.bar' or 'go.Figure':"
echo "=========================================="
grep -n -E "go\.Bar|px\.bar|go\.Figure|graph_objects" "$APP" | head -10

echo "=========================================="
echo "6. Lines containing 'chart' (any case):"
echo "=========================================="
grep -ni "chart" "$APP" | head -15

echo "=========================================="
echo "Done. Paste this output back."
echo "=========================================="
