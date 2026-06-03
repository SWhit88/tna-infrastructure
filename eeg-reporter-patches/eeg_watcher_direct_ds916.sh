#!/usr/bin/env bash
# eeg_watcher_direct_ds916.sh
# RUN ON: P340
# Permanent fix for the ShareSync gap: point the P340 watcher at DS916+ directly
# instead of DS918+. ShareSync has been broken since ~2026-05-27, causing bundles
# to land on DS916+ but never replicate to DS918+. By reading DS916+ directly we
# eliminate ShareSync from the critical path entirely.
#
# This script:
#   1. Locates the source directory constant in watcher.py / config.py
#   2. Backs up the file
#   3. Updates the path: /mnt/nas918/ai-pipeline/eeg-incoming -> /mnt/nas916/EEGOfficeData/eeg-incoming
#   4. Restarts the watcher
#   5. Persists the DS916+ mount in /etc/fstab so it survives reboots
#
# Safe to re-run. Original file is timestamped-backed-up.

set -euo pipefail
cd ~/eeg-reporter
ts=$(date +%Y%m%d_%H%M%S)

OLD_PATH='/mnt/nas918/ai-pipeline/eeg-incoming'
NEW_PATH='/mnt/nas916/EEGOfficeData/eeg-incoming'

echo "===== 1. Sanity: confirm new path is mounted and readable ====="
if ! timeout 10 ls "$NEW_PATH" >/dev/null 2>&1; then
  echo "ERROR: $NEW_PATH is not accessible. Mount DS916+ first:"
  echo "  sudo mount -t cifs //100.86.203.16/EEGOfficeData /mnt/nas916/EEGOfficeData -o username=Nerve916,vers=1.0"
  exit 1
fi
echo "  OK: $NEW_PATH responds"

echo
echo "===== 2. Find files that reference the old path ====="
files_to_patch=$(grep -rlF "$OLD_PATH" ~/eeg-reporter --include='*.py' 2>/dev/null || true)
if [ -z "$files_to_patch" ]; then
  echo "  No .py file mentions $OLD_PATH directly. Checking config.py for any incoming-related setting..."
  grep -n -E 'incoming|watch|nas91[68]' ~/eeg-reporter/config.py 2>/dev/null | head -20 || echo "  (no config.py or no matches)"
  echo
  echo "  Search also in *.json, *.env, *.ini:"
  grep -rlF "$OLD_PATH" ~/eeg-reporter --include='*.json' --include='*.env' --include='*.ini' 2>/dev/null || echo "  (none)"
  echo
  echo "  Manual edit may be required. Aborting auto-patch."
  exit 1
fi

echo "  Files referencing old path:"
echo "$files_to_patch" | sed 's/^/    /'

echo
echo "===== 3. Backup and patch each file ====="
echo "$files_to_patch" | while IFS= read -r f; do
  cp "$f" "${f}.bak.${ts}"
  # Use perl for safe in-place replacement with special chars
  perl -i -pe "s|\Q${OLD_PATH}\E|${NEW_PATH}|g" "$f"
  echo "  patched: $f  (backup: ${f}.bak.${ts})"
done

echo
echo "===== 4. Verify substitution ====="
grep -rF "$NEW_PATH" ~/eeg-reporter --include='*.py' 2>/dev/null | head -10

echo
echo "===== 5. Restart watcher (and dashboard for safety) ====="
sudo fuser -k 8060/tcp 2>/dev/null || true
pkill -9 -f 'python.*main.py' 2>/dev/null || true
pkill -9 -f 'python.*watcher.py' 2>/dev/null || true
pkill -9 -f 'python.*app.py' 2>/dev/null || true
sleep 3

cd ~/eeg-reporter
nohup python3 app.py > ~/eeg-reporter/logs/app.log 2>&1 &
disown
sleep 2
nohup python3 main.py > ~/eeg-reporter/logs/watcher.log 2>&1 &
disown
sleep 3

echo
echo "----- app.log tail -----"
tail -n 10 ~/eeg-reporter/logs/app.log
echo
echo "----- watcher.log tail -----"
tail -n 10 ~/eeg-reporter/logs/watcher.log 2>/dev/null || echo "(no watcher.log yet)"

echo
echo "===== 6. Persist DS916+ mount in /etc/fstab (so it survives reboot) ====="
FSTAB_LINE='//100.86.203.16/EEGOfficeData /mnt/nas916/EEGOfficeData cifs credentials=/etc/cifs-nas916,vers=1.0,_netdev,nofail,x-systemd.automount 0 0'
if grep -qF "/mnt/nas916/EEGOfficeData" /etc/fstab; then
  echo "  fstab already has an entry for /mnt/nas916/EEGOfficeData - leaving alone"
  grep "/mnt/nas916/EEGOfficeData" /etc/fstab
else
  echo "  Creating /etc/cifs-nas916 credentials file..."
  if [ ! -f /etc/cifs-nas916 ]; then
    echo "  Need to write credentials. You'll be prompted for sudo + the Nerve916 password..."
    read -p "  Nerve916 SMB password: " -s NERVE_PW
    echo
    sudo bash -c "cat > /etc/cifs-nas916 <<EOF
username=Nerve916
password=${NERVE_PW}
EOF"
    sudo chmod 600 /etc/cifs-nas916
    sudo chown root:root /etc/cifs-nas916
    echo "  /etc/cifs-nas916 created (mode 600 root:root)"
  fi
  echo "  Appending fstab line..."
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
  echo "  Reloading systemd and triggering automount..."
  sudo systemctl daemon-reload
  sudo mount -a 2>&1 || true
  echo "  fstab entry installed."
fi

echo
echo "===== DONE ====="
echo "Watcher now reads from: $NEW_PATH"
echo "ShareSync is no longer in the critical path."
echo "Dashboard: https://leige-thinkstation-p340.tail7b3d8f.ts.net"
echo
echo "Tail the logs to see new studies being picked up:"
echo "  tail -f ~/eeg-reporter/logs/watcher.log"
