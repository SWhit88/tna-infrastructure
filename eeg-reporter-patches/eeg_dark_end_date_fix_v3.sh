#!/usr/bin/env bash
# eeg_dark_end_date_fix_v3.sh
# DOM inspection revealed the real structure (not react-dates!):
#   <div id="filter-date-range-wrapper" class="dash-datepicker dash-datepicker-input-wrapper">
#     <input id="filter-date-range-start-date" class="dash-datepicker-input dash-datepicker-start-date">
#     <input id="filter-date-range-end-date"   class="dash-datepicker-input dash-datepicker-end-date">
#
# v1/v2 targeted #filter-date-range (which doesn't exist) — useless.
# v3 targets the real IDs/classes via CSS (no JS needed — this is the dash-datepicker
# library which doesn't fight inline styles like react-dates does).
#
# The current dark theme uses `background: var(--nc-surface) !important` on these
# inputs. We override with higher specificity targeting the exact IDs.
set -euo pipefail

CSS=~/eeg-reporter/assets/neurochart-theme.css
JS=~/eeg-reporter/assets/theme-toggle.js
[[ -f "$CSS" ]] || { echo "[!] $CSS missing"; exit 1; }
[[ -f "$JS" ]] || { echo "[!] $JS missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP_CSS="$CSS.bak-$ts-pre-enddate-v3"
BACKUP_JS="$JS.bak-$ts-pre-enddate-v3"
cp "$CSS" "$BACKUP_CSS"
cp "$JS"  "$BACKUP_JS"
echo "[*] CSS backup: $BACKUP_CSS"
echo "[*] JS  backup: $BACKUP_JS"

# Strip prior JS date-input-fix blocks (no longer needed — wrong target anyway)
echo "[*] Removing prior JS DATE_INPUT_DARK_MODE_FIX blocks (wrong target)..."
python3 << PYEOF
import re
with open('$JS') as f:
    src = f.read()
src = re.sub(
    r'\n*// ===== DATE_INPUT_DARK_MODE_FIX[_v0-9]*.*?// ===== /DATE_INPUT_DARK_MODE_FIX[_v0-9]*[^\n]*\n',
    '\n',
    src,
    flags=re.DOTALL
)
# Cleanup any unterminated v1 leftovers
src = re.sub(r'\n*// ===== DATE_INPUT_DARK_MODE_FIX_v1[^\n]*\n.*\Z', '', src, flags=re.DOTALL)
with open('$JS','w') as f:
    f.write(src.rstrip() + '\n')
PYEOF

# Strip prior CSS date-input-fix blocks
echo "[*] Removing prior CSS DATE_INPUT_DARK_MODE blocks..."
python3 << PYEOF
import re
with open('$CSS') as f:
    src = f.read()
src = re.sub(
    r'\n*/\* === DATE_INPUT_DARK_MODE_FIX[_v0-9]* === \*/.*?/\* === /DATE_INPUT_DARK_MODE_FIX[_v0-9]* === \*/\n?',
    '\n',
    src,
    flags=re.DOTALL
)
with open('$CSS','w') as f:
    f.write(src.rstrip() + '\n')
PYEOF

# Bump version
if grep -q "EEG_REPORTER_VERSION" "$JS"; then
    cur=$(grep -oP "EEG_REPORTER_VERSION\s*=\s*'\K[^']+" "$JS" | head -1)
    new=$(python3 -c "
v='$cur'.lstrip('v')
parts=v.split('.')
parts[-1]=str(int(parts[-1])+1)
print('v'+'.'.join(parts))
")
    sed -i "s/EEG_REPORTER_VERSION = '[^']*'/EEG_REPORTER_VERSION = '$new'/" "$JS"
    echo "[+] Bumped version: $cur -> $new"
fi

# Append CSS targeting the REAL element IDs/classes from DOM inspection
cat >> "$CSS" << 'CSSEOF'

/* === DATE_INPUT_DARK_MODE_FIX_v3 === */
/* Real DOM (per DevTools inspection on 2026-05-31):
   <div id="filter-date-range-wrapper" class="dash-datepicker dash-datepicker-input-wrapper">
     <input id="filter-date-range-start-date" class="dash-datepicker-input dash-datepicker-start-date">
     <input id="filter-date-range-end-date"   class="dash-datepicker-input dash-datepicker-end-date">
   The dark theme uses background: var(--nc-surface) which renders dark navy.
   Override with explicit values at high specificity, scoped to dark mode only. */

html body[data-theme="dark"] #filter-date-range-wrapper,
html body[data-theme="dark"] div#filter-date-range-wrapper.dash-datepicker {
    background-color: #f0f4f8 !important;
    background: #f0f4f8 !important;
    border: 1px solid #4a5e7a !important;
}

html body[data-theme="dark"] #filter-date-range-start-date,
html body[data-theme="dark"] #filter-date-range-end-date,
html body[data-theme="dark"] input.dash-datepicker-input,
html body[data-theme="dark"] input.dash-datepicker-start-date,
html body[data-theme="dark"] input.dash-datepicker-end-date {
    background-color: #f0f4f8 !important;
    background: #f0f4f8 !important;
    color: #1a2332 !important;
    border: none !important;
}

html body[data-theme="dark"] #filter-date-range-start-date::placeholder,
html body[data-theme="dark"] #filter-date-range-end-date::placeholder,
html body[data-theme="dark"] input.dash-datepicker-input::placeholder {
    color: #6c757d !important;
    opacity: 1 !important;
}

/* The arrow + clear button + caret icon — keep visible against light bg */
html body[data-theme="dark"] .dash-datepicker-range-arrow,
html body[data-theme="dark"] .dash-datepicker-clear,
html body[data-theme="dark"] .dash-datepicker-caret-icon {
    background-color: #f0f4f8 !important;
    background: #f0f4f8 !important;
    color: #1a2332 !important;
    fill: #1a2332 !important;
}

html body[data-theme="dark"] .dash-datepicker-range-arrow svg,
html body[data-theme="dark"] .dash-datepicker-clear svg,
html body[data-theme="dark"] .dash-datepicker-caret-icon svg,
html body[data-theme="dark"] #filter-date-range-wrapper svg {
    fill: #1a2332 !important;
    stroke: #1a2332 !important;
    color: #1a2332 !important;
}

/* The absolutely-positioned overlay divs inside each input wrapper */
html body[data-theme="dark"] #filter-date-range-wrapper div[style*="position: absolute"],
html body[data-theme="dark"] #filter-date-range-wrapper div[style*="visibility: hidden"] {
    background-color: transparent !important;
    background: transparent !important;
    color: #6c757d !important;
}

/* === /DATE_INPUT_DARK_MODE_FIX_v3 === */
CSSEOF

echo "[+] Appended CSS fix targeting #filter-date-range-wrapper / -start-date / -end-date"

# Add a minimal JS sweep as belt-and-suspenders — targets the REAL IDs now
cat >> "$JS" << 'JSEOF'

// ===== DATE_INPUT_DARK_MODE_FIX_v3 =====
// Belt-and-suspenders: stomp the real DOM IDs in case CSS doesn't win
(function() {
    var LIGHT_BG = '#f0f4f8';
    var DARK_TEXT = '#1a2332';

    function stomp() {
        if (!document.body || document.body.getAttribute('data-theme') !== 'dark') {
            // Clear in light mode
            ['filter-date-range-wrapper','filter-date-range-start-date','filter-date-range-end-date'].forEach(function(id){
                var el = document.getElementById(id);
                if (el) {
                    el.style.removeProperty('background-color');
                    el.style.removeProperty('background');
                    el.style.removeProperty('color');
                }
            });
            return 0;
        }
        var count = 0;
        ['filter-date-range-wrapper','filter-date-range-start-date','filter-date-range-end-date'].forEach(function(id){
            var el = document.getElementById(id);
            if (el) {
                el.style.setProperty('background-color', LIGHT_BG, 'important');
                el.style.setProperty('background', LIGHT_BG, 'important');
                if (el.tagName === 'INPUT') {
                    el.style.setProperty('color', DARK_TEXT, 'important');
                }
                count++;
            }
        });
        // Also stomp all .dash-datepicker-input elements
        document.querySelectorAll('.dash-datepicker-input').forEach(function(el){
            el.style.setProperty('background-color', LIGHT_BG, 'important');
            el.style.setProperty('background', LIGHT_BG, 'important');
            el.style.setProperty('color', DARK_TEXT, 'important');
            count++;
        });
        return count;
    }

    function init() {
        var n = stomp();
        console.log('[EEG] Date dark-mode v3 — stomped ' + n + ' elements');
        setInterval(stomp, 500);
        if (document.body && typeof MutationObserver !== 'undefined') {
            var obs = new MutationObserver(function(muts){
                muts.forEach(function(m){
                    if (m.attributeName === 'data-theme') {
                        setTimeout(stomp, 30);
                        setTimeout(stomp, 200);
                    }
                });
            });
            obs.observe(document.body, {attributes: true, attributeFilter: ['data-theme']});
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        var tries = 0;
        var poll = setInterval(function(){
            tries++;
            if (document.getElementById('filter-date-range-wrapper') || tries > 40) {
                clearInterval(poll);
                init();
            }
        }, 250);
    }
})();
// ===== /DATE_INPUT_DARK_MODE_FIX_v3 =====
JSEOF

echo "[+] Appended JS belt-and-suspenders for real DOM IDs"

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
echo "[*] Verify served CSS contains v3:"
curl -s "http://127.0.0.1:8060/assets/neurochart-theme.css?v=$(date +%s)" | grep -c "DATE_INPUT_DARK_MODE_FIX_v3" || echo "0"

echo
echo "[*] New footer version:"
grep -oP "EEG_REPORTER_VERSION\s*=\s*'\K[^']+" "$JS" | head -1

echo
echo "[✓] Done. HARD-RELOAD (Ctrl+Shift+R)."
echo "    In dark mode, both Start Date and End Date should now show light gray bg + dark text."
echo "    Open DevTools console: '[EEG] Date dark-mode v3 — stomped N elements' (N should be 2+)"
echo
echo "    Rollback:"
echo "      cp $BACKUP_CSS $CSS && cp $BACKUP_JS $JS && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
