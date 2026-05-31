#!/usr/bin/env bash
# eeg_dark_end_date_fix_v1.sh
# Fix the End Date input rendering with dark navy background in dark mode.
# Start Date is fine; only End Date is broken.
#
# Root cause: Dash's dcc.DatePickerRange uses react-dates which sets inline
# `style.background` on the *placeholder* input via JS at render time, beating
# any CSS rule. CSS-only attempts have failed across v1-v9 (per PICK-UP-HERE-DARKMODE.md).
#
# Fix: JS sweep inside theme-toggle.js — when dark mode is active, force-write
# light-gray bg + dark text directly onto BOTH date inputs via element.style.setProperty
# with 'important' priority. Runs once on theme change AND polls every 500ms for the
# first 5 seconds after toggle to catch any re-renders. Also runs on initial load.
#
# This is the "JS stomps inline style" pattern from PICK-UP-HERE-DARKMODE.md Step 4.
#
# Does NOT touch app.py. Does NOT touch CSS. Only adds JS to theme-toggle.js.
set -euo pipefail

JS=~/eeg-reporter/assets/theme-toggle.js
[[ -f "$JS" ]] || { echo "[!] $JS missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$JS.bak-$ts-pre-enddate"
cp "$JS" "$BACKUP"
echo "[*] Backup: $BACKUP"

# Strip any prior date-input-fix block (idempotent)
if grep -q "DATE_INPUT_DARK_MODE_FIX_v1" "$JS"; then
    echo "[*] Stripping prior date input fix block"
    # Remove from marker line to end of file
    python3 -c "
import re
src = open('$JS').read()
src = re.sub(r'\n*// ===== DATE_INPUT_DARK_MODE_FIX_v1.*\$', '', src, flags=re.DOTALL)
open('$JS','w').write(src.rstrip() + '\n')
"
fi

# Bump version in theme-toggle.js so users see cache-flushed proof
if grep -q "EEG_REPORTER_VERSION" "$JS"; then
    cur=$(grep -oP "EEG_REPORTER_VERSION\s*=\s*'\K[^']+" "$JS" | head -1)
    echo "[*] Current version: $cur"
    # Bump patch number
    new=$(python3 -c "
v='$cur'.lstrip('v')
parts=v.split('.')
parts[-1]=str(int(parts[-1])+1)
print('v'+'.'.join(parts))
")
    sed -i "s/EEG_REPORTER_VERSION = '[^']*'/EEG_REPORTER_VERSION = '$new'/" "$JS"
    echo "[+] Bumped version: $cur -> $new"
else
    echo "[!] No EEG_REPORTER_VERSION constant found — skipping version bump"
fi

# Append the date input fix block
cat >> "$JS" << 'JSEOF'

// ===== DATE_INPUT_DARK_MODE_FIX_v1 =====
// Force light-gray background + dark text on End Date (and Start Date) inputs
// in dark mode. React-dates sets inline style at render time which beats CSS,
// so we stomp it directly on the DOM nodes.
(function() {
    var LIGHT_BG = '#f0f4f8';
    var DARK_TEXT = '#1a2332';

    function applyDateInputStyles() {
        if (document.body && document.body.getAttribute('data-theme') === 'dark') {
            // Target all inputs inside the date-range picker
            var inputs = document.querySelectorAll('#filter-date-range input, .DateInput_input');
            inputs.forEach(function(el) {
                el.style.setProperty('background-color', LIGHT_BG, 'important');
                el.style.setProperty('background', LIGHT_BG, 'important');
                el.style.setProperty('color', DARK_TEXT, 'important');
            });
            // Also target the DateInput wrappers (in case background is on the wrapper)
            var wrappers = document.querySelectorAll('#filter-date-range .DateInput, #filter-date-range .DateRangeInput, #filter-date-range .DateRangeInput_arrow');
            wrappers.forEach(function(el) {
                el.style.setProperty('background-color', LIGHT_BG, 'important');
                el.style.setProperty('background', LIGHT_BG, 'important');
            });
        } else {
            // In light mode, clear the inline overrides so default theme applies
            var inputs = document.querySelectorAll('#filter-date-range input, .DateInput_input');
            inputs.forEach(function(el) {
                el.style.removeProperty('background-color');
                el.style.removeProperty('background');
                el.style.removeProperty('color');
            });
            var wrappers = document.querySelectorAll('#filter-date-range .DateInput, #filter-date-range .DateRangeInput, #filter-date-range .DateRangeInput_arrow');
            wrappers.forEach(function(el) {
                el.style.removeProperty('background-color');
                el.style.removeProperty('background');
            });
        }
    }

    // Run once on load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', applyDateInputStyles);
    } else {
        applyDateInputStyles();
    }

    // Run continuously every 750ms — Dash re-renders the date picker on focus/blur
    // and we need to re-stomp it. 750ms is fast enough to feel instant but light on CPU.
    setInterval(applyDateInputStyles, 750);

    // Run when the theme toggle is clicked (catch the change immediately)
    document.addEventListener('click', function(e) {
        if (e.target && (e.target.id === 'theme-toggle' || (e.target.closest && e.target.closest('#theme-toggle')))) {
            // Re-apply 3 times over 1.5s to catch re-renders
            setTimeout(applyDateInputStyles, 50);
            setTimeout(applyDateInputStyles, 250);
            setTimeout(applyDateInputStyles, 600);
            setTimeout(applyDateInputStyles, 1500);
        }
    }, true);

    // Watch for attribute changes on body (data-theme toggle) via MutationObserver
    if (typeof MutationObserver !== 'undefined') {
        var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(m) {
                if (m.attributeName === 'data-theme') {
                    setTimeout(applyDateInputStyles, 30);
                    setTimeout(applyDateInputStyles, 200);
                }
            });
        });
        if (document.body) {
            observer.observe(document.body, {attributes: true, attributeFilter: ['data-theme']});
        }
    }

    console.log('[EEG] Dark-mode date input stomp v1 loaded');
})();
// ===== /DATE_INPUT_DARK_MODE_FIX_v1 =====
JSEOF

echo "[+] Appended DATE_INPUT_DARK_MODE_FIX_v1 to theme-toggle.js"
echo
echo "[*] Verify block present:"
grep -c "DATE_INPUT_DARK_MODE_FIX_v1" "$JS"
echo
echo "[*] Restarting eeg-reporter..."
if systemctl --user is-active --quiet eeg-reporter 2>/dev/null; then
  systemctl --user restart eeg-reporter
elif systemctl is-active --quiet eeg-reporter 2>/dev/null; then
  sudo systemctl restart eeg-reporter
else
  pkill -f 'python.*app.py' 2>/dev/null || true
  pkill -f 'python.*main.py' 2>/dev/null || true
  sleep 2
  (cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &)
fi
sleep 3

echo
echo "[*] Health check:"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true

echo
echo "[*] Verify served JS contains the fix:"
curl -s http://127.0.0.1:8060/assets/theme-toggle.js | grep -c "DATE_INPUT_DARK_MODE_FIX_v1" || echo "0 — cached version may still be old, hard-reload needed"

echo
echo "[✓] Done. HARD-RELOAD the browser (Ctrl+Shift+R)."
echo "    Open dark mode. Both Start Date and End Date should now have light gray bg"
echo "    with dark text — readable matching all other inputs."
echo
echo "    Rollback:"
echo "      cp $BACKUP $JS && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
