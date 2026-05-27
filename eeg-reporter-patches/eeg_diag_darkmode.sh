#!/bin/bash
# Verify dark mode is still wired correctly after today's app.py patches.
set -e
cd ~/eeg-reporter

echo "=========== assets/dark-mode.css ==========="
if [ -f assets/dark-mode.css ]; then
    wc -l assets/dark-mode.css
    head -5 assets/dark-mode.css
else
    echo "  MISSING"
fi
echo

echo "=========== assets/dark-mode.js ==========="
if [ -f assets/dark-mode.js ]; then
    wc -l assets/dark-mode.js
    head -10 assets/dark-mode.js
else
    echo "  MISSING"
fi
echo

echo "=========== dark-mode references in app.py ==========="
grep -n "dark[-_]mode\|theme-toggle\|darkMode\|data-theme" app.py | head -20 || echo "  (none found)"
echo

echo "=========== Are the assets being served? ==========="
curl -sI http://localhost:8060/assets/dark-mode.css | head -3
echo
curl -sI http://localhost:8060/assets/dark-mode.js | head -3
echo

echo "=========== Toggle button in current rendered HTML ==========="
curl -s http://localhost:8060/ | grep -oE 'id="theme-toggle"[^>]*|class="[^"]*theme[^"]*"' | head -5 || echo "  (no toggle id/class in rendered page)"
echo

echo "=========== Looking for the default-to-dark code ==========="
grep -n "localStorage\|getItem.*theme\|setAttribute.*theme\|dark.*default" app.py assets/dark-mode.js 2>/dev/null | head -10 || echo "  (no localStorage / default-dark code found)"
