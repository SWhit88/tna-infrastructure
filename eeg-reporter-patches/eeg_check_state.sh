#!/usr/bin/env bash
# RUN ON: P340
# Quick state check — where are we, what does the watcher see, what's in drafts?
set -u
ts="$(date '+%Y-%m-%d %H:%M:%S')"
echo "=== EEG state check — $ts ==="

echo
echo "--- 1. main.py / app.py processes ---"
pgrep -af "main.py|app.py" || echo "  NONE RUNNING"

echo
echo "--- 2. Port 8060 listener ---"
ss -ltnp 2>/dev/null | grep -E ':8060\b' || echo "  port 8060 NOT listening"

echo
echo "--- 3. Where is watcher reading from? (grep watcher.py for incoming path) ---"
grep -nE "eeg-incoming|incoming_dir|INCOMING|watch_dir" ~/eeg-reporter/watcher.py 2>/dev/null | head -20
grep -nE "eeg-incoming|INCOMING|incoming" ~/eeg-reporter/config.py 2>/dev/null | head -10

echo
echo "--- 4. Mount status ---"
mount | grep -E "nas916|nas918|EEGOffice|ai-pipeline" || echo "  no NAS mounts found"

echo
echo "--- 5. DS918+ ai-pipeline/eeg-incoming — last 20 by mtime ---"
ls -lat /mnt/nas918/ai-pipeline/eeg-incoming/ 2>/dev/null | head -25 || echo "  DS918+ path not accessible"

echo
echo "--- 6. DS916+ EEGOfficeData/eeg-incoming — last 20 .done sentinels ---"
ls -lat /mnt/nas916/EEGOfficeData/eeg-incoming/*.done 2>/dev/null | head -20 || echo "  DS916+ path not accessible"

echo
echo "--- 7. The 4 catch-up studies (FA00133O/Q/T/V) — present on DS918+? ---"
for s in FA00133O FA00133Q FA00133T FA00133V; do
  echo "  $s:"
  ls -la /mnt/nas918/ai-pipeline/eeg-incoming/${s}.* 2>/dev/null | sed 's/^/    /' || echo "    (missing on DS918+)"
done

echo
echo "--- 8. Drafts folder — last 10 by mtime ---"
ls -lat ~/eeg-reporter/reports/drafts/ 2>/dev/null | head -15 || echo "  drafts folder missing"

echo
echo "--- 9. App log — last 60 lines ---"
tail -60 ~/eeg-reporter/logs/app.log 2>/dev/null || echo "  no app.log"

echo
echo "=== done ==="
