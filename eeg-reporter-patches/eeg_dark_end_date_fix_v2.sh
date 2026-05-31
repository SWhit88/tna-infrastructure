#!/usr/bin/env bash
# eeg_dark_end_date_fix_v2.sh
# v1 stomped inputs and a few wrappers but End Date wrapper bg stayed dark.
# v2 is heavy artillery:
#   - Walks EVERY descendant of #filter-date-range (div/span/input) and sets light bg
#   - Sets BOTH `background-color` AND `background` (react-dates uses shorthand sometimes)
#   - Injects a <style> tag with ::placeholder rules (placeholder text color can't be set via inline style)
#   - Uses MutationObserver on the subtree to catch every re-render instantly
#   - Adds console.log diagnostics so we can verify the script is finding elements
#
# Idempotent: strips any prior DATE_INPUT_DARK_MODE_FIX_v* block first.
set -euo pipefail

JS=~/eeg-reporter/assets/theme-toggle.js
[[ -f "$JS" ]] || { echo "[!] $JS missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$JS.bak-$ts-pre-enddate-v2"
cp "$JS" "$BACKUP"
echo "[*] Backup: $BACKUP"

# Strip prior date-input-fix blocks (v1 and any earlier attempts)
echo "[*] Stripping prior date input fix blocks..."
python3 << PYEOF
import re
with open('$JS') as f:
    src = f.read()
# Remove any block matching DATE_INPUT_DARK_MODE_FIX (v1, v2, etc.)
src = re.sub(
    r'\n*// ===== DATE_INPUT_DARK_MODE_FIX[_v0-9]*.*?// ===== /DATE_INPUT_DARK_MODE_FIX[_v0-9]*.*?\n',
    '\n',
    src,
    flags=re.DOTALL
)
# Also clean any unterminated v1 block (if it was appended without a closing comment)
src = re.sub(r'\n*// ===== DATE_INPUT_DARK_MODE_FIX_v1.*\$', '', src, flags=re.DOTALL)
with open('$JS','w') as f:
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

# Append v2 fix
cat >> "$JS" << 'JSEOF'

// ===== DATE_INPUT_DARK_MODE_FIX_v2 =====
// Walk EVERY descendant of #filter-date-range and stomp bg. Inject <style> for ::placeholder.
(function() {
    var LIGHT_BG = '#f0f4f8';
    var DARK_TEXT = '#1a2332';
    var PLACEHOLDER_TEXT = '#6c757d';
    var STYLE_TAG_ID = '__date_dark_mode_style__';

    function ensureStyleTag() {
        if (document.getElementById(STYLE_TAG_ID)) return;
        var s = document.createElement('style');
        s.id = STYLE_TAG_ID;
        s.textContent = [
            // Dark-mode-only ::placeholder + bg rules with extreme specificity
            'html body[data-theme="dark"] #filter-date-range input::placeholder { color: ' + PLACEHOLDER_TEXT + ' !important; opacity: 1 !important; }',
            'html body[data-theme="dark"] #filter-date-range input::-webkit-input-placeholder { color: ' + PLACEHOLDER_TEXT + ' !important; opacity: 1 !important; }',
            'html body[data-theme="dark"] #filter-date-range input::-moz-placeholder { color: ' + PLACEHOLDER_TEXT + ' !important; opacity: 1 !important; }',
            'html body[data-theme="dark"] #filter-date-range,',
            'html body[data-theme="dark"] #filter-date-range *:not(svg):not(path) {',
            '  background-color: ' + LIGHT_BG + ' !important;',
            '  background: ' + LIGHT_BG + ' !important;',
            '  color: ' + DARK_TEXT + ' !important;',
            '}',
            'html body[data-theme="dark"] #filter-date-range input {',
            '  background-color: ' + LIGHT_BG + ' !important;',
            '  background: ' + LIGHT_BG + ' !important;',
            '  color: ' + DARK_TEXT + ' !important;',
            '}',
            // The X-clear button arrow icon — make it visible against light bg
            'html body[data-theme="dark"] #filter-date-range svg { fill: ' + DARK_TEXT + ' !important; color: ' + DARK_TEXT + ' !important; background: transparent !important; }',
            // The arrow between Start/End — keep transparent
            'html body[data-theme="dark"] #filter-date-range .DateRangePickerInput_arrow { background: transparent !important; background-color: transparent !important; }'
        ].join('\n');
        document.head.appendChild(s);
        console.log('[EEG] Date dark-mode style tag injected');
    }

    function stomp() {
        if (!document.body || document.body.getAttribute('data-theme') !== 'dark') {
            // Clear any inline overrides in light mode
            var allLight = document.querySelectorAll('#filter-date-range, #filter-date-range *');
            allLight.forEach(function(el) {
                if (el.tagName === 'SVG' || el.tagName === 'PATH') return;
                el.style.removeProperty('background-color');
                el.style.removeProperty('background');
                el.style.removeProperty('color');
            });
            return 0;
        }
        var container = document.getElementById('filter-date-range');
        if (!container) return 0;
        var all = container.querySelectorAll('*');
        var count = 0;
        all.forEach(function(el) {
            var tag = el.tagName;
            if (tag === 'SVG' || tag === 'PATH') return;  // leave icons alone
            el.style.setProperty('background-color', LIGHT_BG, 'important');
            el.style.setProperty('background', LIGHT_BG, 'important');
            if (tag === 'INPUT') {
                el.style.setProperty('color', DARK_TEXT, 'important');
            }
            count++;
        });
        // Also stomp the container itself
        container.style.setProperty('background-color', LIGHT_BG, 'important');
        container.style.setProperty('background', LIGHT_BG, 'important');
        return count;
    }

    function init() {
        ensureStyleTag();
        var n = stomp();
        console.log('[EEG] Date dark-mode stomp v2 — initial pass affected ' + n + ' elements');

        // Continuous safety net every 500ms
        setInterval(function() {
            ensureStyleTag();
            stomp();
        }, 500);

        // MutationObserver on the date container subtree — catches every re-render instantly
        var container = document.getElementById('filter-date-range');
        if (container && typeof MutationObserver !== 'undefined') {
            var obs = new MutationObserver(function() { stomp(); });
            obs.observe(container, {childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class']});
            console.log('[EEG] MutationObserver attached to #filter-date-range');
        }

        // Watch for body data-theme changes
        if (document.body && typeof MutationObserver !== 'undefined') {
            var bodyObs = new MutationObserver(function(muts) {
                muts.forEach(function(m) {
                    if (m.attributeName === 'data-theme') {
                        setTimeout(stomp, 20);
                        setTimeout(stomp, 150);
                        setTimeout(stomp, 400);
                    }
                });
            });
            bodyObs.observe(document.body, {attributes: true, attributeFilter: ['data-theme']});
        }

        // Click on theme toggle — re-stomp aggressively
        document.addEventListener('click', function(e) {
            var t = e.target;
            if (t && (t.id === 'theme-toggle' || (t.closest && t.closest('#theme-toggle')))) {
                setTimeout(stomp, 30);
                setTimeout(stomp, 200);
                setTimeout(stomp, 500);
                setTimeout(stomp, 1000);
            }
        }, true);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        // Container may not exist yet — retry until it does
        var tries = 0;
        var poll = setInterval(function() {
            tries++;
            if (document.getElementById('filter-date-range') || tries > 40) {
                clearInterval(poll);
                init();
            }
        }, 250);
    }
})();
// ===== /DATE_INPUT_DARK_MODE_FIX_v2 =====
JSEOF

echo "[+] Appended DATE_INPUT_DARK_MODE_FIX_v2 to theme-toggle.js"

# Verify only one fix block present
n=$(grep -c "DATE_INPUT_DARK_MODE_FIX_v2" "$JS")
echo "[*] v2 marker count: $n (expect 2 — open + close comments)"

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
echo "[*] Verify served JS contains v2:"
curl -s "http://127.0.0.1:8060/assets/theme-toggle.js?v=$(date +%s)" | grep -c "DATE_INPUT_DARK_MODE_FIX_v2" || echo "0"

echo
echo "[*] New footer version:"
grep -oP "EEG_REPORTER_VERSION\s*=\s*'\K[^']+" "$JS" | head -1

echo
echo "[✓] Done. HARD-RELOAD (Ctrl+Shift+R or Ctrl+F5)."
echo "    Then in dark mode, open DevTools (F12) console."
echo "    You should see: '[EEG] Date dark-mode stomp v2 — initial pass affected N elements'"
echo "    where N > 0. If N = 0, paste the console output."
echo
echo "    Rollback:"
echo "      cp $BACKUP $JS && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
