#!/usr/bin/env bash
# After the suppress_callback_exceptions patch:
# 1. Confirm the patch is in the running app
# 2. Show only NEW errors in the log (since restart)
# 3. Show all callback POSTs in the last 60 seconds with status codes
set -euo pipefail

echo "=================== Patch verification ==================="
grep -n "suppress_callback_exceptions" ~/eeg-reporter/app.py | head -5
echo

echo "=================== Running process ==================="
ps -ef | grep -E "[p]ython3.*main.py" | head -3
echo

LOG=~/eeg-reporter/logs/app.log

# Find restart line, then everything after it
START_LINE=$(grep -n "Dash is running on" "$LOG" | tail -1 | cut -d: -f1)
if [ -z "$START_LINE" ]; then
  START_LINE=1
fi
echo "=================== Log from last restart (line $START_LINE onward) ==================="

# Show all errors since restart
echo "--- Errors since restart ---"
tail -n +"$START_LINE" "$LOG" | grep -E "ERROR|Traceback|IndexError|Exception" | tail -30
echo

# Show all dash-update-component POSTs since restart with their status code
echo "--- All callback POSTs since restart (last 40) ---"
tail -n +"$START_LINE" "$LOG" | grep "_dash-update-component" | tail -40
echo

echo "=================== Curl test from P340 to itself ==================="
# Send an empty POST to /_dash-update-component to confirm responding
curl -sS -o /dev/null -w "Root /  -> HTTP %{http_code}\n" http://127.0.0.1:8060/
curl -sS -o /dev/null -w "_dash-layout -> HTTP %{http_code}\n" http://127.0.0.1:8060/_dash-layout
curl -sS -o /dev/null -w "_dash-dependencies -> HTTP %{http_code}\n" http://127.0.0.1:8060/_dash-dependencies
