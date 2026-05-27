#!/bin/bash
# Read-only — find where channel count is computed and where it's fed into the prompt.
cd ~/eeg-reporter

echo "=========== Files in repo ==========="
ls -1 *.py
echo
echo "=========== Where 'channel' / 'n_channels' / 'ch_names' is referenced ==========="
grep -rn -E "channel|n_channels|ch_names|num_channels" --include="*.py" . | grep -v __pycache__ | head -60
echo
echo "=========== Where montage / 10-20 / scalp is referenced ==========="
grep -rn -iE "montage|10-20|scalp|electrode" --include="*.py" . | grep -v __pycache__ | head -30
echo
echo "=========== Prompt text(s) sent to Ollama ==========="
grep -rn -E "ollama|prompt|gemma" --include="*.py" . | grep -v __pycache__ | head -40
echo
echo "=========== Last produced report JSON — what fields exist? ==========="
LATEST_JSON=$(ls -1t reports/*.json 2>/dev/null | head -1)
echo "Latest: $LATEST_JSON"
if [ -n "$LATEST_JSON" ]; then
    python3 -c "
import json, sys
with open('$LATEST_JSON') as f:
    d = json.load(f)
def walk(o, prefix=''):
    if isinstance(o, dict):
        for k,v in o.items():
            if isinstance(v, (dict, list)) and v:
                print(f'{prefix}{k}:')
                walk(v, prefix+'  ')
            else:
                val = str(v)[:120]
                print(f'{prefix}{k}: {val}')
    elif isinstance(o, list):
        print(f'{prefix}[list of {len(o)} items]')
walk(d)
"
fi
