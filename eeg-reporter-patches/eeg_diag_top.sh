#!/bin/bash
# Show the actual top of eeg_analyzer.py so we can place SCALP_10_20 correctly.
cd ~/eeg-reporter

# Restore again first so we have a clean file to inspect
LATEST_BAK=$(ls -1t eeg_analyzer.py.bak-* | grep -v pre-v2 | head -1)
echo "=========== Restoring from: $LATEST_BAK ==========="
cp "$LATEST_BAK" eeg_analyzer.py
echo
echo "=========== First 60 lines of restored eeg_analyzer.py (line-numbered) ==========="
nl -ba eeg_analyzer.py | head -60
echo
echo "=========== Syntax check on restored file ==========="
python3 -c "import ast; ast.parse(open('eeg_analyzer.py').read()); print('PARSES OK')"
