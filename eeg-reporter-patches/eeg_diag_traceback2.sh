#!/bin/bash
set -e
cd ~/eeg-reporter

echo "=========== 50 lines BEFORE each IndexError (the actual stack) ==========="
grep -n -B50 "IndexError: list index out of range" logs/app.log | tail -120
