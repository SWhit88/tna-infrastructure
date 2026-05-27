#!/bin/bash
cd ~/eeg-reporter
echo "=========== Lines 270-295 of eeg_analyzer.py (current broken state) ==========="
sed -n '270,295p' eeg_analyzer.py
echo
echo "=========== Same range in the .bak file (pre-patch original) ==========="
LATEST_BAK=$(ls -1t eeg_analyzer.py.bak-* 2>/dev/null | head -1)
echo "Backup: $LATEST_BAK"
if [ -n "$LATEST_BAK" ]; then
    sed -n '270,295p' "$LATEST_BAK"
fi
echo
echo "=========== Lines containing 'EXCLUDE_PREFIX' in current file ==========="
grep -n "EXCLUDE_PREFIX" eeg_analyzer.py
echo
echo "=========== Lines containing 'EXCLUDE_PREFIX' in the .bak ==========="
grep -n "EXCLUDE_PREFIX" "$LATEST_BAK"
