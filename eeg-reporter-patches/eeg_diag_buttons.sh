#!/bin/bash
# Inspect the state of the three action buttons in app.py:
#   Save draft, Sign and finalize, Save and preview
set -e
cd ~/eeg-reporter

echo "=========== Button-like elements in app.py ==========="
grep -nE 'html\.Button|dbc\.Button|"Save|"Sign|"Preview|"Finalize|"Draft' app.py | head -40
echo

echo "=========== All button ids (id=\"...-btn\" or similar) ==========="
grep -nE 'id="[^"]*(save|sign|preview|draft|finalize|submit)[^"]*"' app.py | head -20
echo

echo "=========== Callback decorators that reference those ids ==========="
grep -nE 'Input\("[^"]*(save|sign|preview|draft|finalize)[^"]*"|State\("[^"]*(save|sign|preview|draft|finalize)[^"]*"' app.py | head -20
echo

echo "=========== Tail of app.py (last 60 lines) to see appended callbacks ==========="
tail -60 app.py
echo

echo "=========== Recent log entries with 500 or Exception or Traceback ==========="
tail -200 ~/eeg-reporter/logs/app.log 2>/dev/null | grep -E "500|Exception|Traceback|Error" | tail -20 || echo "  (no errors)"
echo

echo "=========== Browser-side: open dev tools, check console for errors ==========="
echo "  Dashboard: http://100.113.163.65:8060"
echo "  In dev console (F12 -> Console) watch for callback errors when clicking the buttons."
