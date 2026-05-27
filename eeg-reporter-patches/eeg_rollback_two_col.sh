#!/bin/bash
# Rollback the broken two-column patch.
set -e
cd ~/eeg-reporter

BAK=$(ls -1t app.py.bak-*-pre-two-column 2>/dev/null | head -n 1)
if [ -z "$BAK" ]; then
    echo "FATAL: no app.py.bak-*-pre-two-column found"
    exit 1
fi
echo "[*] Restoring from: $BAK"
cp "$BAK" app.py
echo "[+] Restored."

echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

echo
echo "[*] Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
echo
echo "[*] Tail of app.log:"
tail -n 15 ~/eeg-reporter/logs/app.log
echo
echo "[✓] Rolled back. Hard-reload the dashboard (Ctrl+Shift+R)."
