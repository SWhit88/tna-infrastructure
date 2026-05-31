#!/usr/bin/env bash
# eeg_dark_chart_pdr_v2.sh
# v1 caused the chart to render with bars positioned off-screen (Plotly layout
# broke when our Python patch added font/xaxis/yaxis kwargs incorrectly).
# v2 plan:
#   1. ROLLBACK the app.py changes from v1 (restore from v1's backup if present,
#      else surgically remove the added kwargs).
#   2. Keep the CSS PDR strip fix (it worked — PDR text now readable).
#   3. Replace the chart CSS with a SIMPLER, less-invasive ruleset: force dark
#      text on SVG <text> in dark mode, dark stroke on axis paths, but NOTHING
#      that affects layout or positioning.
#   4. Darken the date input placeholder color so it's readable.
#   5. Also darken placeholder text on other inputs in dark mode (search, etc.).
#
# Safe: AST-validated app.py changes, idempotent CSS appends.
set -euo pipefail

APP=~/eeg-reporter/app.py
CSS=~/eeg-reporter/assets/neurochart-theme.css
JS=~/eeg-reporter/assets/theme-toggle.js
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }
[[ -f "$CSS" ]] || { echo "[!] $CSS missing"; exit 1; }
[[ -f "$JS" ]]  || { echo "[!] $JS missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP_APP="$APP.bak-$ts-pre-v2"
BACKUP_CSS="$CSS.bak-$ts-pre-v2"
cp "$APP" "$BACKUP_APP"
cp "$CSS" "$BACKUP_CSS"
echo "[*] APP backup: $BACKUP_APP"
echo "[*] CSS backup: $BACKUP_CSS"

# ============================================================
# STEP 1: Roll back app.py to before v1's Plotly patches.
# Find the most recent v1 backup and restore it. If not found, do surgical undo.
# ============================================================
V1_BACKUP=$(ls -t ${APP}.bak-*-pre-chart-pdr-v1 2>/dev/null | head -1 || true)
if [[ -n "$V1_BACKUP" && -f "$V1_BACKUP" ]]; then
    echo "[*] Found v1 backup: $V1_BACKUP — restoring app.py to pre-v1 state"
    cp "$V1_BACKUP" "$APP"
    echo "[+] app.py rolled back"
else
    echo "[!] No v1 backup found, attempting surgical removal..."
    python3 << 'PYEOF'
import re, ast, sys
APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()
# Remove kwargs we added: font=dict(color="#1a2332"), xaxis=dict(... gridcolor="#e0e0e0", linecolor="#1a2332"), yaxis=...
patterns = [
    r',?\s*font=dict\(color="#1a2332"\)',
    r',?\s*xaxis=dict\(color="#1a2332", tickfont=dict\(color="#1a2332"\), gridcolor="#e0e0e0", linecolor="#1a2332"\)',
    r',?\s*yaxis=dict\(color="#1a2332", tickfont=dict\(color="#1a2332"\), gridcolor="#e0e0e0", linecolor="#1a2332"\)',
]
removed = 0
for p in patterns:
    n = len(re.findall(p, src))
    src = re.sub(p, '', src)
    removed += n
# Remove id="chart-bandpower" we added
src = re.sub(r'id="chart-bandpower",\s*', '', src)
try:
    ast.parse(src)
except SyntaxError as e:
    print(f"FATAL: ast error after rollback: {e}", file=sys.stderr)
    sys.exit(1)
open(APP,'w').write(src)
print(f"[+] Surgically removed {removed} v1 additions from app.py")
PYEOF
    if [[ $? -ne 0 ]]; then
        echo "[!] Surgical rollback failed. Restoring from v2 pre-edit backup."
        cp "$BACKUP_APP" "$APP"
        exit 1
    fi
fi

# ============================================================
# STEP 2: Strip prior CSS chart/pdr blocks (we'll re-add cleaner)
# ============================================================
echo "[*] Stripping prior CHART_PDR_DARK_MODE_FIX CSS blocks..."
python3 << PYEOF
import re
with open('$CSS') as f:
    src = f.read()
src = re.sub(
    r'\n*/\* === CHART_PDR_DARK_MODE_FIX[_v0-9]* === \*/.*?/\* === /CHART_PDR_DARK_MODE_FIX[_v0-9]* === \*/\n?',
    '\n', src, flags=re.DOTALL
)
src = re.sub(
    r'\n*/\* === DARK_PLACEHOLDER_FIX[_v0-9]* === \*/.*?/\* === /DARK_PLACEHOLDER_FIX[_v0-9]* === \*/\n?',
    '\n', src, flags=re.DOTALL
)
with open('$CSS','w') as f:
    f.write(src.rstrip() + '\n')
PYEOF

# ============================================================
# STEP 3: Append cleaner CSS: PDR strip readable + placeholder darkened
#          + chart text SVG dark (no layout-affecting rules)
# ============================================================
cat >> "$CSS" << 'CSSEOF'

/* === CHART_PDR_DARK_MODE_FIX_v2 === */
/* Goal: make text readable on the white card areas inside #report-detail
   without affecting layout or sizing. */

/* PDR summary strip + body text on white cards in dark mode. */
html body[data-theme="dark"] #report-detail p,
html body[data-theme="dark"] #report-detail span,
html body[data-theme="dark"] #report-detail strong,
html body[data-theme="dark"] #report-detail b,
html body[data-theme="dark"] #report-detail label,
html body[data-theme="dark"] #report-detail li {
    color: #1a2332 !important;
}

/* Keep big headers (Wallace, Jerry) bright on dark page area */
html body[data-theme="dark"] #report-detail > h1,
html body[data-theme="dark"] #report-detail > h2,
html body[data-theme="dark"] #report-detail > h3 {
    color: #e8eef5 !important;
}

/* Section titles like "HEADER FIELDS" stay teal-ish for visibility */
html body[data-theme="dark"] #report-detail h4 {
    color: #1e3a5f !important;
}

/* Plotly chart text — force dark on the white-bg chart so labels render.
   IMPORTANT: only target text and stroke colors. Do NOT set positioning,
   width, height, transform, or background — those would break Plotly's
   internal layout math. */
html body[data-theme="dark"] .js-plotly-plot text,
html body[data-theme="dark"] #chart-bandpower text,
html body[data-theme="dark"] .dash-graph text {
    fill: #1a2332 !important;
}

html body[data-theme="dark"] .js-plotly-plot .xaxislayer-above path.domain,
html body[data-theme="dark"] .js-plotly-plot .yaxislayer-above path.domain,
html body[data-theme="dark"] .js-plotly-plot .xtick > path,
html body[data-theme="dark"] .js-plotly-plot .ytick > path,
html body[data-theme="dark"] .dash-graph .xaxis path.domain,
html body[data-theme="dark"] .dash-graph .yaxis path.domain {
    stroke: #1a2332 !important;
}

html body[data-theme="dark"] .js-plotly-plot .gridlayer path,
html body[data-theme="dark"] .dash-graph .gridlayer path {
    stroke: #e0e0e0 !important;
}

/* === /CHART_PDR_DARK_MODE_FIX_v2 === */

/* === DARK_PLACEHOLDER_FIX_v1 === */
/* Date input placeholders ("Start Date", "End Date") and search placeholder
   were rendered in #6c757d which is too light on the #f0f4f8 bg in dark mode. */

html body[data-theme="dark"] #filter-date-range-start-date::placeholder,
html body[data-theme="dark"] #filter-date-range-end-date::placeholder,
html body[data-theme="dark"] input.dash-datepicker-input::placeholder {
    color: #2d4a6e !important;
    opacity: 1 !important;
}

html body[data-theme="dark"] input[type="text"]::placeholder,
html body[data-theme="dark"] input[type="search"]::placeholder,
html body[data-theme="dark"] textarea::placeholder {
    color: #2d4a6e !important;
    opacity: 0.85 !important;
}

/* === /DARK_PLACEHOLDER_FIX_v1 === */
CSSEOF

echo "[+] Appended v2 CSS"

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

# Verify app.py still parses
python3 -c "import ast; ast.parse(open('$APP').read())" || { echo "[!] app.py syntax error!"; cp "$BACKUP_APP" "$APP"; exit 1; }

echo
echo "[*] Verify:"
grep -c "CHART_PDR_DARK_MODE_FIX_v2" "$CSS"
grep -c "DARK_PLACEHOLDER_FIX_v1" "$CSS"
echo "[*] Confirm app.py has NO v1 patch leftovers:"
grep -c 'font=dict(color="#1a2332")' "$APP" || true
grep -c 'id="chart-bandpower"' "$APP" || true

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
sleep 4

echo
echo "[*] Health check:"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true

echo
echo "[*] Tail of app log:"
tail -10 /tmp/eeg-reporter.log 2>/dev/null || tail -10 ~/eeg-reporter/logs/app.log 2>/dev/null || true

echo
echo "[✓] Done. HARD-RELOAD (Ctrl+Shift+R)."
echo "    Expected in dark mode:"
echo "    - Start Date / End Date placeholder text readable (darker)"
echo "    - Search box placeholder readable"
echo "    - PDR summary strip readable (already worked in v1)"
echo "    - Chart: hopefully back to v1.0.12 state (light mode works,"
echo "      dark mode shows white rectangles — we'll fix that next via"
echo "      DOM inspection of why traces don't render)"
echo
echo "    Rollback:"
echo "      cp $BACKUP_APP $APP && cp $BACKUP_CSS $CSS && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
