#!/bin/bash
# Diagnostic only — read-only. Show the current shape of app.py and all .bak files.
cd ~/eeg-reporter
echo "=========== app.py.bak-* timeline (oldest first) ==========="
ls -1tr app.py.bak-* 2>/dev/null
echo
echo "=========== current app.py size + md5 ==========="
wc -l app.py
md5sum app.py
echo
echo "=========== search-box references in current app.py ==========="
grep -n "search-box\|search-suggest\|_eeg_search" app.py | head -40
echo
echo "=========== all @app.callback decorators in current app.py ==========="
grep -n "@app.callback" app.py
echo
echo "=========== Input/Output(\"search-box\" lines ==========="
grep -nE 'Input\("search-box"|Output\("search-box"|Input\("search-suggest"|Output\("search-suggest"' app.py
echo
echo "=========== Earliest backup's search-box references ==========="
EARLIEST=$(ls -1tr app.py.bak-* 2>/dev/null | head -1)
echo "Earliest backup: $EARLIEST"
if [ -n "$EARLIEST" ]; then
    grep -n "search-box\|search-suggest" "$EARLIEST" | head -20
    echo
    echo "Earliest backup callback count:"
    grep -c "@app.callback" "$EARLIEST"
fi
echo
echo "=========== Current callback count ==========="
grep -c "@app.callback" app.py
