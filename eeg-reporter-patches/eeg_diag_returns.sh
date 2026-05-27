#!/bin/bash
# Read-only — find every return statement inside update_list and count its values.
cd ~/eeg-reporter

echo "=========== Lines 108-195: update_list function body ==========="
sed -n '108,195p' app.py
echo
echo "=========== All 'return' statements in update_list (lines 108-195) ==========="
awk 'NR>=108 && NR<=195 && /return/ { print NR": "$0 }' app.py
echo
echo "=========== Comma count per return (rough output-arity estimate) ==========="
awk 'NR>=108 && NR<=195 && /return/ {
    line = $0
    # Strip "return " keyword
    sub(/^[[:space:]]*return[[:space:]]*/, "", line)
    # Count top-level commas (not inside parens/brackets)
    depth = 0; commas = 0
    n = length(line)
    for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (c == "(" || c == "[" || c == "{") depth++
        else if (c == ")" || c == "]" || c == "}") depth--
        else if (c == "," && depth == 0) commas++
    }
    print NR": "(commas+1)" values  --  "$0
}' app.py
