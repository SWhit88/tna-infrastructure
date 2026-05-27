#!/bin/bash
# Read-only — show the update_list callback decorator + function signature + first body lines
cd ~/eeg-reporter

echo "=========== update_list callback decorator (full, with newlines) ==========="
awk '/^@app\.callback\(Output\("report-list"/,/^def /' app.py | head -30
echo
echo "=========== Exact Input count in update_list decorator ==========="
awk '/^@app\.callback\(Output\("report-list"/,/^def /' app.py | grep -oE 'Input\("[^"]+","[^"]+"\)' | nl
echo
echo "=========== Layout components referenced as Inputs — confirming they EXIST in layout ==========="
for comp in refresh search-box filter-status filter-referring-md filter-ordering-md filter-year filter-month filter-date-range sort-by list-refresh-trigger; do
    count=$(grep -c "id=\"$comp\"" app.py)
    echo "id=\"$comp\"   present in layout: $count"
done
echo
echo "=========== Function signature line for update_list ==========="
grep -A 1 '^@app\.callback(Output("report-list"' app.py | tail -1
# Actually grab the def line that follows
sed -n '/^@app\.callback(Output("report-list"/,/^def /p' app.py | tail -3
echo
echo "=========== sort-by id presence in layout ==========="
grep -n 'sort-by\|"sort-by"' app.py | head -10
echo
echo "=========== filter-date-range id presence in layout ==========="
grep -n 'filter-date-range\|"filter-date-range"' app.py | head -10
echo
echo "=========== filter-ordering-md id presence in layout ==========="
grep -n 'filter-ordering-md\|"filter-ordering-md"' app.py | head -10
