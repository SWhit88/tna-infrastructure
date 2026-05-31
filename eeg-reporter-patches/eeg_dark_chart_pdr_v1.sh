#!/usr/bin/env bash
# eeg_dark_chart_pdr_v1.sh
# Fix two dark-mode issues confirmed by DevTools screenshot:
#   1. Chart renders as blank white rectangles — Plotly traces don't draw because
#      dark theme overrides chart colors. Fix: edit app.py fig.update_layout to add
#      explicit font.color, axis colors, and wrap chart in an identifiable container.
#   2. PDR summary bar (PDR: X Hz | Symmetry: ... | Assessment: ...) renders as
#      white-on-white. Fix: CSS rule forcing dark text on that strip in dark mode.
#
# Two-part patch: app.py (Python anchor splice) + neurochart-theme.css (append rule).
# AST-validated, idempotent (strips prior chart/PDR fix blocks first).
set -euo pipefail

APP=~/eeg-reporter/app.py
CSS=~/eeg-reporter/assets/neurochart-theme.css
JS=~/eeg-reporter/assets/theme-toggle.js
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }
[[ -f "$CSS" ]] || { echo "[!] $CSS missing"; exit 1; }
[[ -f "$JS" ]]  || { echo "[!] $JS missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP_APP="$APP.bak-$ts-pre-chart-pdr-v1"
BACKUP_CSS="$CSS.bak-$ts-pre-chart-pdr-v1"
cp "$APP" "$BACKUP_APP"
cp "$CSS" "$BACKUP_CSS"
echo "[*] APP backup: $BACKUP_APP"
echo "[*] CSS backup: $BACKUP_CSS"

# ============================================================
# PATCH 1: app.py — fig.update_layout add explicit colors + chart container ID
# ============================================================
python3 << 'PYEOF'
import re, ast, sys

APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()
orig = src

# Find any fig.update_layout(...) call and add font.color, xaxis, yaxis colors if missing.
# Strategy: search for `fig.update_layout(` and patch the keyword args.
# We need a parens-balanced extraction.

def find_call(text, start):
    """Find balanced parens starting at `(` position. Returns (open_idx, close_idx)."""
    depth = 0
    i = start
    while i < len(text):
        c = text[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return (start, i)
        elif c in '"\'':
            # Skip string literal
            quote = c
            i += 1
            while i < len(text) and text[i] != quote:
                if text[i] == '\\':
                    i += 1
                i += 1
        i += 1
    return None

# Find fig.update_layout(
m = re.search(r'fig\.update_layout\s*\(', src)
if not m:
    print("FATAL: fig.update_layout not found in app.py", file=sys.stderr)
    sys.exit(1)

paren_open = m.end() - 1  # position of '('
span = find_call(src, paren_open)
if not span:
    print("FATAL: could not find balanced parens for fig.update_layout", file=sys.stderr)
    sys.exit(1)
call_start, call_end = m.start(), span[1] + 1  # full span including ')'
inner_start = paren_open + 1
inner_end = span[1]

inner = src[inner_start:inner_end]
print(f"[*] fig.update_layout inner kwargs (chars {inner_start}-{inner_end}):")
for ln in inner.split('\n')[:15]:
    print(f"    | {ln}")

# Check if font= or xaxis= already present with color spec
needs_font = ('font=' not in inner) and ('font =' not in inner)
needs_xaxis_color = not re.search(r'xaxis\s*=\s*dict\([^)]*color', inner)
needs_yaxis_color = not re.search(r'yaxis\s*=\s*dict\([^)]*color', inner)

additions = []
if needs_font:
    additions.append('font=dict(color="#1a2332")')
if needs_xaxis_color:
    additions.append('xaxis=dict(color="#1a2332", tickfont=dict(color="#1a2332"), gridcolor="#e0e0e0", linecolor="#1a2332")')
if needs_yaxis_color:
    additions.append('yaxis=dict(color="#1a2332", tickfont=dict(color="#1a2332"), gridcolor="#e0e0e0", linecolor="#1a2332")')

if additions:
    # Insert before the closing ')' — handle trailing comma/newline
    inner_stripped = inner.rstrip()
    # Determine the indent from the last non-empty line
    lines_of_inner = inner.split('\n')
    # Find indent of first kwarg line for matching style
    indent_kw = ''
    for ln in lines_of_inner:
        if ln.strip() and not ln.strip().startswith('#'):
            indent_kw = ln[:len(ln) - len(ln.lstrip())]
            break
    if not indent_kw:
        indent_kw = '    '
    
    sep = ',\n' + indent_kw
    addition_text = sep + sep.join(additions)
    # If inner ends with ',' already, just append; else prepend ','
    if inner_stripped.endswith(','):
        new_inner = inner_stripped + '\n' + indent_kw + (sep.join(additions)).lstrip('\n').lstrip().replace(', ' + indent_kw, ',\n' + indent_kw) + '\n'
    else:
        new_inner = inner_stripped + addition_text + '\n'
    src = src[:inner_start] + new_inner + src[inner_end:]
    print(f"[+] Added to fig.update_layout: {[a.split('=')[0] for a in additions]}")
else:
    print("[*] fig.update_layout already has font/xaxis/yaxis colors — skipping")

# Add id="chart-bandpower" to dcc.Graph if not already present
graph_match = re.search(r'dcc\.Graph\s*\([^)]*figure\s*=\s*fig', src)
if graph_match:
    # Get the full Graph call
    paren_o = src.find('(', graph_match.start())
    gspan = find_call(src, paren_o)
    if gspan:
        graph_inner_start = paren_o + 1
        graph_inner_end = gspan[1]
        graph_inner = src[graph_inner_start:graph_inner_end]
        if 'id=' not in graph_inner and 'id =' not in graph_inner:
            new_graph_inner = 'id="chart-bandpower", ' + graph_inner.lstrip()
            src = src[:graph_inner_start] + new_graph_inner + src[graph_inner_end:]
            print('[+] Added id="chart-bandpower" to dcc.Graph')

# AST validation
try:
    ast.parse(src)
except SyntaxError as e:
    print(f"FATAL: post-patch SyntaxError: {e}", file=sys.stderr)
    err_line = e.lineno or 0
    lines_v = src.split('\n')
    for i in range(max(0, err_line-5), min(len(lines_v), err_line+5)):
        marker = ' >>>' if i+1 == err_line else '    '
        print(f"{marker} {i+1:4d}: {lines_v[i]}", file=sys.stderr)
    sys.exit(2)

if src != orig:
    open(APP, 'w').write(src)
    print("[+] app.py written")
else:
    print("[*] No changes to app.py")
PYEOF

rc=$?
if [[ $rc -ne 0 ]]; then
  echo "[!] app.py patch failed (rc=$rc). Restoring."
  cp "$BACKUP_APP" "$APP"
  exit $rc
fi

# ============================================================
# PATCH 2: CSS for PDR summary bar + chart container
# ============================================================
echo "[*] Stripping prior chart/PDR CSS blocks..."
python3 << PYEOF
import re
with open('$CSS') as f:
    src = f.read()
src = re.sub(
    r'\n*/\* === CHART_PDR_DARK_MODE_FIX[_v0-9]* === \*/.*?/\* === /CHART_PDR_DARK_MODE_FIX[_v0-9]* === \*/\n?',
    '\n', src, flags=re.DOTALL
)
with open('$CSS','w') as f:
    f.write(src.rstrip() + '\n')
PYEOF

cat >> "$CSS" << 'CSSEOF'

/* === CHART_PDR_DARK_MODE_FIX_v1 === */
/* The PDR summary strip (PDR: X Hz | Symmetry: ... | Assessment: ...) and the
   chart container both inherit dark bg + white text from the body. They sit on
   a white card so the text becomes invisible. Force dark text on these strips
   in dark mode, scoped narrowly so other dark-mode UI isn't affected. */

/* PDR summary bar — usually rendered as a div with light bg above the chart.
   Anchor: it's inside #report-detail (or .report-detail) and contains the
   "PDR:" or "Symmetry:" text. We can't pick by text content in CSS, but the
   visible strip in the screenshot is the FIRST direct child div of the chart
   wrapper. We'll target any element inside #report-detail / .report-detail
   that has the explicit white/light bg from inline style or class. */

html body[data-theme="dark"] #report-detail,
html body[data-theme="dark"] .report-detail,
html body[data-theme="dark"] div#report-detail * {
    /* Don't blanket-override — let nested cards keep their colors. */
}

/* Plotly chart container: force light text-bearing strip to use dark text.
   The PDR strip above the chart is typically a sibling of the chart .js-plotly-plot. */
html body[data-theme="dark"] #report-detail div[style*="background"]:not([style*="rgb(45"]):not([style*="#1a"]):not([style*="#0f"]),
html body[data-theme="dark"] #report-detail p,
html body[data-theme="dark"] #report-detail span,
html body[data-theme="dark"] #report-detail strong,
html body[data-theme="dark"] #report-detail b {
    color: #1a2332 !important;
}

/* But keep header text (Wallace, Jerry) and red status banner */
html body[data-theme="dark"] #report-detail h1,
html body[data-theme="dark"] #report-detail h2,
html body[data-theme="dark"] #report-detail h3 {
    color: #e8eef5 !important;  /* light text for headers on dark bg */
}
html body[data-theme="dark"] #report-detail .status-banner,
html body[data-theme="dark"] #report-detail [style*="color:#cc"],
html body[data-theme="dark"] #report-detail [style*="color: #cc"],
html body[data-theme="dark"] #report-detail [style*="color:red"],
html body[data-theme="dark"] #report-detail [style*="color: red"] {
    /* leave reds alone */
}

/* Plotly chart text/axes/traces — force dark on the SVG since chart bg is white */
html body[data-theme="dark"] .js-plotly-plot .main-svg text,
html body[data-theme="dark"] .js-plotly-plot text,
html body[data-theme="dark"] .js-plotly-plot .xtitle,
html body[data-theme="dark"] .js-plotly-plot .ytitle,
html body[data-theme="dark"] .js-plotly-plot .gtitle,
html body[data-theme="dark"] .js-plotly-plot .annotation-text-g text {
    fill: #1a2332 !important;
    color: #1a2332 !important;
}

html body[data-theme="dark"] .js-plotly-plot .xaxislayer-above path.xtick,
html body[data-theme="dark"] .js-plotly-plot .yaxislayer-above path.ytick,
html body[data-theme="dark"] .js-plotly-plot .xaxis path.domain,
html body[data-theme="dark"] .js-plotly-plot .yaxis path.domain {
    stroke: #1a2332 !important;
}

html body[data-theme="dark"] .js-plotly-plot .gridlayer path {
    stroke: #e0e0e0 !important;
}

/* === /CHART_PDR_DARK_MODE_FIX_v1 === */
CSSEOF

echo "[+] Appended CHART_PDR_DARK_MODE_FIX_v1 to CSS"

# Bump version in JS
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

echo
echo "[*] Verify anchors:"
grep -c "CHART_PDR_DARK_MODE_FIX_v1" "$CSS"
grep -n 'font=dict(color="#1a2332")' "$APP" | head -1 || echo "(font color may already have been present)"
grep -n 'id="chart-bandpower"' "$APP" | head -1 || echo "(no chart-bandpower id — Graph may already have one)"

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
tail -20 /tmp/eeg-reporter.log 2>/dev/null || tail -20 ~/eeg-reporter/logs/app.log 2>/dev/null || true

echo
echo "[✓] Done. HARD-RELOAD (Ctrl+Shift+R)."
echo "    Open Wallace, Jerry in dark mode. You should see:"
echo "    1. PDR summary strip text now readable (dark text on white bg)"
echo "    2. Chart bars + axes + labels rendered (dark text/axes on white bg)"
echo
echo "    Rollback:"
echo "      cp $BACKUP_APP $APP && cp $BACKUP_CSS $CSS && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
