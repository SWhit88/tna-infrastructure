#!/usr/bin/env bash
# eeg_ordering_md_buttons_v1.sh
# Replace the "Ordering MD (partial name)" text input with 3 quick-filter buttons:
#   [Dr. Whitney] [Dr. Blackburn] [Other]
# Radio-style: click one to filter, click again to clear, click another to switch.
# All other filters (search, status, referring, year, month, date range, sort) are preserved.
# Two-column drafts/finalized layout is preserved.
#
# Approach:
# 1. Replace the dcc.Input(id="filter-ordering-md", ...) with html.Div containing 3 buttons + dcc.Store
# 2. Modify the update_list callback to read from the Store instead of the old Input value
# 3. Add a callback to manage button state (active/inactive styling + Store value)
# 4. Patch the filter logic in update_list to do whitney/blackburn/other matching
set -euo pipefail

APP=~/eeg-reporter/app.py
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$APP.bak-$ts-pre-ordering-buttons"
cp "$APP" "$BACKUP"
echo "[*] Backup: $BACKUP"

python3 << 'PYEOF'
import re, ast, sys

APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()
orig = src

# ===== PATCH 1: replace the Ordering MD text input with button group + Store =====
# Find the Ordering MD line and its surrounding dcc.Input(...) block
# The current code uses dcc.Input(id="filter-ordering-md", placeholder="Ordering MD (partial name)", ...)
# We'll search for the id literal and replace from "dcc.Input(" up to the matching ")"
ordering_re = re.compile(
    r'dcc\.Input\(\s*id\s*=\s*"filter-ordering-md"[^)]*\)',
    re.DOTALL
)
m = ordering_re.search(src)
if not m:
    print("FATAL: could not find dcc.Input(id=\"filter-ordering-md\", ...)", file=sys.stderr)
    sys.exit(1)

replacement = '''html.Div([
                dcc.Store(id="ordering-md-filter", data=None),
                html.Div([
                    html.Button("Dr. Whitney", id="btn-md-whitney", n_clicks=0,
                                style={'flex':'1','padding':'6px 4px','fontSize':'9pt','fontWeight':'600',
                                       'border':'1px solid #1e3a5f','borderRadius':'4px 0 0 4px',
                                       'backgroundColor':'#ffffff','color':'#1e3a5f','cursor':'pointer',
                                       'borderRight':'none'}),
                    html.Button("Dr. Blackburn", id="btn-md-blackburn", n_clicks=0,
                                style={'flex':'1','padding':'6px 4px','fontSize':'9pt','fontWeight':'600',
                                       'border':'1px solid #1e3a5f','borderRadius':'0',
                                       'backgroundColor':'#ffffff','color':'#1e3a5f','cursor':'pointer',
                                       'borderRight':'none'}),
                    html.Button("Other", id="btn-md-other", n_clicks=0,
                                style={'flex':'1','padding':'6px 4px','fontSize':'9pt','fontWeight':'600',
                                       'border':'1px solid #1e3a5f','borderRadius':'0 4px 4px 0',
                                       'backgroundColor':'#ffffff','color':'#1e3a5f','cursor':'pointer'})
                ], style={'display':'flex','width':'100%','marginBottom':'4px'}),
                html.Div("Ordering MD", style={'fontSize':'8pt','color':'#777','textAlign':'center','marginBottom':'4px'})
            ])'''
src = src[:m.start()] + replacement + src[m.end():]
print("[+] Replaced Ordering MD input with button group")

# ===== PATCH 2: change the update_list callback signature =====
# Old: Input("filter-ordering-md","value")
# New: Input("ordering-md-filter","data")  (reads from Store, same position in args)
old_input = 'Input("filter-ordering-md","value")'
new_input = 'Input("ordering-md-filter","data")'
if old_input not in src:
    print(f"FATAL: cannot find {old_input!r} in callback", file=sys.stderr)
    sys.exit(1)
src = src.replace(old_input, new_input)
print("[+] Updated update_list callback Input from filter-ordering-md to ordering-md-filter")

# ===== PATCH 3: update the filter logic in update_list body =====
# The function signature has `ord_md` as a param (unchanged - same position).
# Find the line that filters by ord_md as a substring match and replace it
# with whitney/blackburn/other matching.
#
# Current pattern is typically:
#    if ord_md and ord_md.lower() not in str(rpt.get('ordering_physician','')).lower():
#        continue
# OR similar. We search for any reference to ord_md inside the filter loop.

# Find the substring filter for ord_md - it should be near the other "if year and..." filters
ord_filter_patterns = [
    r"if ord_md and ord_md\.lower\(\) not in str\(rpt\.get\('ordering_physician',''\)\)\.lower\(\):\s*\n\s*continue",
    r"if ord_md and ord_md\.lower\(\) not in \(rpt\.get\('ordering_physician',''\) or ''\)\.lower\(\):\s*\n\s*continue",
    r"if ord_md:\s*\n\s*if ord_md\.lower\(\) not in str\(rpt\.get\('ordering_physician',''\)\)\.lower\(\):\s*\n\s*continue",
]
match = None
for pat in ord_filter_patterns:
    m = re.search(pat, src)
    if m:
        match = m
        break

if not match:
    # Fallback: find any line containing "ord_md" inside the update_list function body
    # We'll look for any line that uses ord_md in a conditional
    print("[!] Standard ord_md filter pattern not found, doing broader scan...")
    # Try a very loose match
    loose = re.search(r"(\s+)if ord_md[^:]*:\s*\n\s*(?:if[^:]+:\s*\n\s*)?continue", src)
    if loose:
        match = loose
        print("[+] Found loose ord_md filter")

if not match:
    print("FATAL: could not find ord_md filter logic in update_list. Manual edit needed.", file=sys.stderr)
    print("Search for 'ord_md' in app.py near line 120-150", file=sys.stderr)
    # Restore from backup
    sys.exit(1)

# Determine indent from match
m_indent = re.match(r'^\s*', match.group(0).split('\n')[1] if '\n' in match.group(0) else match.group(0))
indent = '        '  # 8 spaces — typical for inside a for loop in this codebase

new_filter = f'''{indent}# Ordering MD button filter (whitney / blackburn / other)
{indent}_ord_str = str(rpt.get('ordering_physician','') or '').lower()
{indent}if ord_md == 'whitney':
{indent}    if 'whitney' not in _ord_str:
{indent}        continue
{indent}elif ord_md == 'blackburn':
{indent}    if 'blackburn' not in _ord_str:
{indent}        continue
{indent}elif ord_md == 'other':
{indent}    if 'whitney' in _ord_str or 'blackburn' in _ord_str:
{indent}        continue'''

src = src[:match.start()] + '\n' + new_filter + src[match.end():]
print("[+] Updated ord_md filter logic for whitney/blackburn/other matching")

# ===== PATCH 4: add the button-state callback =====
# Append a callback that toggles the Store value and the button styles
# We add it just before "if __name__" or at the end of the file before the main block

callback_code = '''

# ----- Ordering MD button group: toggles Store value and button active styling -----
@app.callback(
    Output("ordering-md-filter", "data"),
    Output("btn-md-whitney", "style"),
    Output("btn-md-blackburn", "style"),
    Output("btn-md-other", "style"),
    Input("btn-md-whitney", "n_clicks"),
    Input("btn-md-blackburn", "n_clicks"),
    Input("btn-md-other", "n_clicks"),
    dash.State("ordering-md-filter", "data"),
    prevent_initial_call=False
)
def _toggle_ordering_md_buttons(_w, _b, _o, current):
    ctx = dash.callback_context
    base_style = {
        'flex': '1', 'padding': '6px 4px', 'fontSize': '9pt', 'fontWeight': '600',
        'border': '1px solid #1e3a5f', 'backgroundColor': '#ffffff',
        'color': '#1e3a5f', 'cursor': 'pointer'
    }
    active_style = {
        'flex': '1', 'padding': '6px 4px', 'fontSize': '9pt', 'fontWeight': '600',
        'border': '1px solid #0891B2', 'backgroundColor': '#0891B2',
        'color': '#ffffff', 'cursor': 'pointer'
    }
    w_style = {**base_style, 'borderRadius': '4px 0 0 4px', 'borderRight': 'none'}
    b_style = {**base_style, 'borderRadius': '0', 'borderRight': 'none'}
    o_style = {**base_style, 'borderRadius': '0 4px 4px 0'}
    w_active = {**active_style, 'borderRadius': '4px 0 0 4px'}
    b_active = {**active_style, 'borderRadius': '0'}
    o_active = {**active_style, 'borderRadius': '0 4px 4px 0'}

    if not ctx.triggered:
        return current, w_style, b_style, o_style

    btn = ctx.triggered[0]['prop_id'].split('.')[0]
    new_val = None
    if btn == 'btn-md-whitney':
        new_val = None if current == 'whitney' else 'whitney'
    elif btn == 'btn-md-blackburn':
        new_val = None if current == 'blackburn' else 'blackburn'
    elif btn == 'btn-md-other':
        new_val = None if current == 'other' else 'other'

    return (new_val,
            w_active if new_val == 'whitney' else w_style,
            b_active if new_val == 'blackburn' else b_style,
            o_active if new_val == 'other' else o_style)
'''

# Insert before the "if __name__" guard (or app.run / app.run_server call)
guard_match = re.search(r'\n(if __name__\s*==\s*[\'"]__main__[\'"]:)', src)
if guard_match:
    src = src[:guard_match.start()] + callback_code + src[guard_match.start():]
    print("[+] Added ordering-md button callback before __main__ guard")
else:
    # Append to end of file
    src = src.rstrip() + '\n' + callback_code + '\n'
    print("[+] Appended ordering-md button callback to end of file")

# ===== Final AST validation =====
try:
    ast.parse(src)
except SyntaxError as e:
    print(f"FATAL: post-patch SyntaxError: {e}", file=sys.stderr)
    print(f"Restoring from backup", file=sys.stderr)
    import shutil
    sys.exit(2)

# Write
open(APP, 'w').write(src)
print("[+] File written successfully")
PYEOF

rc=$?
if [[ $rc -ne 0 ]]; then
  echo "[!] Python patch failed (rc=$rc). Restoring from backup."
  cp "$BACKUP" "$APP"
  exit $rc
fi

# Verify critical anchors still present
echo
echo "[*] Verify critical anchors still present:"
grep -n "HEADER_FIELDS = " "$APP" | head -1
grep -n "ALL_EDITS = " "$APP" | head -1
grep -n "_SAVE_STATES = " "$APP" | head -1
grep -n "def _resolve_report_path" "$APP" | head -1
grep -n "ordering-md-filter" "$APP" | head -3
grep -n "btn-md-whitney" "$APP" | head -3

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
echo "[✓] Done. Hard-reload (Ctrl+Shift+R) and check the sidebar."
echo "    The Ordering MD text input is replaced with 3 buttons:"
echo "    [Dr. Whitney] [Dr. Blackburn] [Other]"
echo "    Click one to filter list; click again to clear."
echo
echo "    If anything looks broken, rollback with:"
echo "      cp $BACKUP $APP && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
