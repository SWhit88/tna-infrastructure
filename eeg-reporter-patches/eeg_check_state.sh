#!/usr/bin/env bash
# RUN ON: P340
# Quick state check — confirms the eeg-reporter pipeline is healthy.
# Updated 2026-06-04 to match the new architecture (systemd --user service,
# /mnt/nas916-direct mount, single-process Dash+watcher).
set -u
ts="$(date '+%Y-%m-%d %H:%M:%S')"
echo "=== EEG state check — $ts ==="

echo
echo "--- A. eeg-reporter processes (should be ONE: main.py) ---"
ps -ef | grep -E "[m]ain\.py|[e]eg-reporter/app\.py" | grep -v "ai-pipeline\|neurochart\|budget"
echo "  (no standalone app.py should appear here)"

echo
echo "--- B. port 8060 listener (should be the main.py PID above) ---"
ss -ltnp 2>/dev/null | grep -E ':8060\b' || echo "  port 8060 NOT listening"

echo
echo "--- C. systemd --user service status ---"
systemctl --user is-active eeg-reporter.service 2>&1
systemctl --user status eeg-reporter.service --no-pager -l 2>&1 | head -15

echo
echo "--- D. config: what path does the watcher read? ---"
grep -nE "EEG_INCOMING|eeg-incoming" ~/eeg-reporter/config.py 2>/dev/null

echo
echo "--- E. nas916-direct mount (the watcher's source) ---"
mount | grep -E "nas916-direct" || echo "  *** /mnt/nas916-direct NOT MOUNTED ***"
ls -ld /mnt/nas916-direct/eeg-incoming 2>&1

echo
echo "--- F. fstab persistence for nas916-direct ---"
grep -nE "nas916-direct" /etc/fstab 2>/dev/null || echo "  *** no fstab entry — mount will be lost at reboot ***"

echo
echo "--- G. recent .done sentinels on DS916+ (last 10) ---"
ls -lat /mnt/nas916-direct/eeg-incoming/*.done 2>/dev/null | head -10 || echo "  cannot list — mount issue"

echo
echo "--- H. recent watcher log (last 30 lines) ---"
tail -30 ~/eeg-reporter/logs/eeg-reporter.log 2>/dev/null

echo
echo "--- I. recent drafts/reports (last 10 by mtime) ---"
ls -lat ~/eeg-reporter/reports/ 2>/dev/null | head -12

echo
echo "=== Healthy signals ==="
echo "  * A: ONE main.py process, no standalone app.py"
echo "  * B: :8060 held by that same PID"
echo "  * C: 'active (running)' — NOT 'activating auto-restart'"
echo "  * E: /mnt/nas916-direct mounted"
echo "  * F: fstab entry present"
echo "  * H: 'Watching /mnt/nas916-direct/eeg-incoming...' present, no 'Address already in use', no 'EEG_INCOMING does not exist'"
echo "=== done ==="
