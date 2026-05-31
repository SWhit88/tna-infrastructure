#!/usr/bin/env bash
# eeg_ordering_md_buttons_v5.sh
# Builds on v4 — assumes v4 has been applied (button group + Store + callback in place).
# Adds three fixes:
#   1. New [All] button at the front so the group is [All] [Dr. Whitney] [Dr. Blackburn] [Other].
#      [All] is highlighted when no filter is active.
#   2. Blackburn matcher uses substring "blackbur" so typo "Blackbur" still matches.
#   3. Dedupe the filtered list by (patient_id, recording_date) — keeps newest-modified copy.
#      Done AFTER all filtering, BEFORE sort.
#
# This patch is idempotent for the [All] button (won't double-add if already present)
# but assumes ord_md filter logic and the toggle callback exist from v4.
set -euo pipefail

APP=~/eeg-reporter/app.py
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$APP.bak-$ts-pre-v5"
cp "$APP" "$BACKUP"
echo "[*] Backup: $BACKUP"

python3 << 'PYEOF'
import re, ast, sys

APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()

# ============================================================
# Sanity: v4 anchors must exist
# ============================================================
for needle in ['btn-md-whitney', 'btn-md-blackburn', 'btn-md-other', 'ordering-md-filter', '_ord_str']:
    if needle not in src:
        print(f"FATAL: v4 anchor {needle!r} missing — apply v4 first.", file=sys.stderr)
        sys.exit(1)

# ============================================================
# FIX 1: Add [All] button at front of button group + wire into callback
# ============================================================
# 1a. Add the new button before Dr. Whitney button in the layout
#     The whitney button block looks like:
#       html.Button("Dr. Whitney", id="btn-md-whitney", n_clicks=0,
#                   style={...'borderRadius':'4px 0 0 4px'...'borderRight':'none'}),
#     We need to:
#       - change whitney's borderRadius from '4px 0 0 4px' to '0'  (no longer leftmost)
#       - insert [All] button before it with borderRadius '4px 0 0 4px'
#
# We use a literal anchor for the whitney button line.

if 'btn-md-all' in src:
    print("[*] [All] button already present — skipping insertion")
else:
    whitney_anchor = 'html.Button("Dr. Whitney", id="btn-md-whitney", n_clicks=0,'
    if whitney_anchor not in src:
        print(f"FATAL: cannot find whitney button anchor", file=sys.stderr)
        sys.exit(1)

    all_button = '''html.Button("All", id="btn-md-all", n_clicks=0,
                                style={'flex':'0 0 50px','padding':'6px 4px','fontSize':'9pt','fontWeight':'600',
                                       'border':'1px solid #1e3a5f','borderRadius':'4px 0 0 4px',
                                       'backgroundColor':'#0891B2','color':'#ffffff','cursor':'pointer',
                                       'borderRight':'none'}),
                    '''
    src = src.replace(whitney_anchor, all_button + whitney_anchor, 1)
    print("[+] Inserted [All] button before Dr. Whitney")

    # Change whitney's borderRadius from '4px 0 0 4px' to '0' since All is now leftmost.
    # Be precise: only the whitney button's first borderRadius.
    # The whitney style line in v4 was:
    #   'border':'1px solid #1e3a5f','borderRadius':'4px 0 0 4px',
    # We need to change ONLY whitney's. The blackburn button also has 'borderRadius':'0',
    # so we have to be careful. Use the context: whitney has '...4px 0 0 4px','backgroundColor':'#ffffff','color':'#1e3a5f','cursor':'pointer',\n                                       'borderRight':'none'}),
    # Search-and-replace the whitney block specifically:
    whitney_old_radius = "'border':'1px solid #1e3a5f','borderRadius':'4px 0 0 4px',\n                                       'backgroundColor':'#ffffff','color':'#1e3a5f','cursor':'pointer',\n                                       'borderRight':'none'}),\n                    html.Button(\"Dr. Blackburn\""
    whitney_new_radius = "'border':'1px solid #1e3a5f','borderRadius':'0','backgroundColor':'#ffffff','color':'#1e3a5f','cursor':'pointer','borderRight':'none'}),\n                    html.Button(\"Dr. Blackburn\""
    if whitney_old_radius in src:
        src = src.replace(whitney_old_radius, whitney_new_radius, 1)
        print("[+] Updated whitney button borderRadius to '0' (no longer leftmost)")
    else:
        print("[!] Could not surgically update whitney borderRadius — buttons may look squared on the left of whitney")

# 1b. Update the callback to add btn-md-all as an Input and add an "all" branch
#     Find the toggle callback block — anchor on the function def
toggle_fn_anchor = 'def _toggle_ordering_md_buttons('
if toggle_fn_anchor not in src:
    print("FATAL: toggle callback function not found", file=sys.stderr)
    sys.exit(1)

# Replace the entire callback decorator + function with a new version that handles [All].
# Find from '@app.callback(\n    Output("ordering-md-filter", "data"),' through the end of the function.
cb_start_marker = '@app.callback(\n    Output("ordering-md-filter", "data"),'
cb_start_idx = src.find(cb_start_marker)
if cb_start_idx == -1:
    print("FATAL: callback decorator start not found", file=sys.stderr)
    sys.exit(1)

# Use AST to find the end of the function _toggle_ordering_md_buttons
tree = ast.parse(src)
toggle_fn_node = None
for n in ast.walk(tree):
    if isinstance(n, ast.FunctionDef) and n.name == '_toggle_ordering_md_buttons':
        toggle_fn_node = n
        break
if not toggle_fn_node:
    print("FATAL: _toggle_ordering_md_buttons function not found via AST", file=sys.stderr)
    sys.exit(1)

# Convert end line/col to byte offset
def line_col_to_offset(text, line, col):
    cur = 0
    for i, ln in enumerate(text.split('\n'), start=1):
        if i == line:
            return cur + col
        cur += len(ln) + 1
    return cur

cb_end_idx = line_col_to_offset(src, toggle_fn_node.end_lineno, toggle_fn_node.end_col_offset)

new_callback_block = '''@app.callback(
    Output("ordering-md-filter", "data"),
    Output("btn-md-all", "style"),
    Output("btn-md-whitney", "style"),
    Output("btn-md-blackburn", "style"),
    Output("btn-md-other", "style"),
    Input("btn-md-all", "n_clicks"),
    Input("btn-md-whitney", "n_clicks"),
    Input("btn-md-blackburn", "n_clicks"),
    Input("btn-md-other", "n_clicks"),
    dash.State("ordering-md-filter", "data"),
    prevent_initial_call=False
)
def _toggle_ordering_md_buttons(_a, _w, _b, _o, current):
    ctx = dash.callback_context
    base_style = {
        'padding': '6px 4px', 'fontSize': '9pt', 'fontWeight': '600',
        'border': '1px solid #1e3a5f', 'backgroundColor': '#ffffff',
        'color': '#1e3a5f', 'cursor': 'pointer'
    }
    active_style = {
        'padding': '6px 4px', 'fontSize': '9pt', 'fontWeight': '600',
        'border': '1px solid #0891B2', 'backgroundColor': '#0891B2',
        'color': '#ffffff', 'cursor': 'pointer'
    }
    # Per-button base styles with their flex + borderRadius + borderRight
    a_base = {**base_style, 'flex': '0 0 50px', 'borderRadius': '4px 0 0 4px', 'borderRight': 'none'}
    w_base = {**base_style, 'flex': '1', 'borderRadius': '0', 'borderRight': 'none'}
    b_base = {**base_style, 'flex': '1', 'borderRadius': '0', 'borderRight': 'none'}
    o_base = {**base_style, 'flex': '1', 'borderRadius': '0 4px 4px 0'}
    a_active = {**active_style, 'flex': '0 0 50px', 'borderRadius': '4px 0 0 4px', 'borderRight': 'none'}
    w_active = {**active_style, 'flex': '1', 'borderRadius': '0', 'borderRight': 'none'}
    b_active = {**active_style, 'flex': '1', 'borderRadius': '0', 'borderRight': 'none'}
    o_active = {**active_style, 'flex': '1', 'borderRadius': '0 4px 4px 0'}

    # Determine new value
    new_val = current
    if ctx.triggered:
        btn = ctx.triggered[0]['prop_id'].split('.')[0]
        if btn == 'btn-md-all':
            new_val = None
        elif btn == 'btn-md-whitney':
            new_val = None if current == 'whitney' else 'whitney'
        elif btn == 'btn-md-blackburn':
            new_val = None if current == 'blackburn' else 'blackburn'
        elif btn == 'btn-md-other':
            new_val = None if current == 'other' else 'other'

    return (
        new_val,
        a_active if new_val is None else a_base,
        w_active if new_val == 'whitney' else w_base,
        b_active if new_val == 'blackburn' else b_base,
        o_active if new_val == 'other' else o_base,
    )'''

src = src[:cb_start_idx] + new_callback_block + src[cb_end_idx:]
print("[+] Replaced toggle callback with [All]-aware version")

# ============================================================
# FIX 2: Update blackburn matcher to use substring 'blackbur' (typo-tolerant)
# ============================================================
old_bb_filter = "elif ord_md == 'blackburn':\n        if 'blackburn' not in _ord_str:\n            continue"
new_bb_filter = "elif ord_md == 'blackburn':\n        if 'blackbur' not in _ord_str:\n            continue"
if old_bb_filter in src:
    src = src.replace(old_bb_filter, new_bb_filter, 1)
    print("[+] Patched blackburn matcher to 'blackbur' substring (typo-tolerant)")
else:
    print("[!] Blackburn filter pattern not in expected form — checking alternatives...")
    # Try with different indent
    alt = re.search(r"elif ord_md == 'blackburn':\s*\n(\s*)if 'blackburn' not in _ord_str:\s*\n\s*continue", src)
    if alt:
        ind = alt.group(1)
        new_alt = f"elif ord_md == 'blackburn':\n{ind}if 'blackbur' not in _ord_str:\n{ind}    continue"
        src = src[:alt.start()] + new_alt + src[alt.end():]
        print(f"[+] Patched blackburn matcher (alternate indent {len(ind)} spaces)")
    else:
        print("FATAL: cannot find blackburn matcher", file=sys.stderr)
        sys.exit(1)

# Also update the 'other' check to use 'blackbur' substring so typo is grouped correctly
old_other = "elif ord_md == 'other':\n        if 'whitney' in _ord_str or 'blackburn' in _ord_str:\n            continue"
new_other = "elif ord_md == 'other':\n        if 'whitney' in _ord_str or 'blackbur' in _ord_str:\n            continue"
if old_other in src:
    src = src.replace(old_other, new_other, 1)
    print("[+] Patched 'other' check to also exclude 'blackbur' substring")
else:
    alt = re.search(r"elif ord_md == 'other':\s*\n(\s*)if 'whitney' in _ord_str or 'blackburn' in _ord_str:\s*\n\s*continue", src)
    if alt:
        ind = alt.group(1)
        new_alt = f"elif ord_md == 'other':\n{ind}if 'whitney' in _ord_str or 'blackbur' in _ord_str:\n{ind}    continue"
        src = src[:alt.start()] + new_alt + src[alt.end():]
        print(f"[+] Patched 'other' check (alternate indent {len(ind)} spaces)")
    else:
        print("[!] 'other' check not patched — Blackbur typos may incorrectly land in Other")

# ============================================================
# FIX 3: Dedupe filtered list by (patient_id, recording_date)
# ============================================================
# The filtered list is built then sorted then split into drafts/signed.
# We inject dedup AFTER the `for path, rpt, findings in rpts:` loop completes,
# BEFORE the sort block. Anchor: the line `def _date_key(rpt):` is right after the loop.

dedup_anchor = '    def _date_key(rpt):'
if dedup_anchor not in src:
    print("FATAL: dedup anchor (def _date_key) not found", file=sys.stderr)
    sys.exit(1)

if '# DEDUP: keep newest by mtime per (patient_id, recording_date)' in src:
    print("[*] Dedup already present — skipping")
else:
    dedup_block = '''    # DEDUP: keep newest by mtime per (patient_id, recording_date)
    import os as _os
    _seen = {}
    for _p, _r, _f in filtered:
        _key = ((_r.get('patient_id','') or '').strip().lower(),
                (_r.get('recording_date','') or '')[:10])
        try:
            _mt = _os.path.getmtime(_p)
        except Exception:
            _mt = 0
        if _key not in _seen or _mt > _seen[_key][1]:
            _seen[_key] = ((_p, _r, _f), _mt)
    filtered = [v[0] for v in _seen.values()]

'''
    src = src.replace(dedup_anchor, dedup_block + dedup_anchor, 1)
    print("[+] Inserted dedup block (by patient_id + recording_date, keeps newest mtime)")

# ============================================================
# Final AST validation
# ============================================================
try:
    ast.parse(src)
except SyntaxError as e:
    print(f"FATAL: post-patch SyntaxError: {e}", file=sys.stderr)
    err_line = e.lineno or 0
    lines_v = src.split('\n')
    for i in range(max(0, err_line-8), min(len(lines_v), err_line+8)):
        marker = ' >>>' if i+1 == err_line else '    '
        print(f"{marker} {i+1:4d}: {lines_v[i]}", file=sys.stderr)
    sys.exit(2)

open(APP, 'w').write(src)
print("[+] File written successfully")
PYEOF

rc=$?
if [[ $rc -ne 0 ]]; then
  echo "[!] Python patch failed (rc=$rc). Restoring from backup."
  cp "$BACKUP" "$APP"
  exit $rc
fi

echo
echo "[*] Verify anchors:"
grep -n "btn-md-all" "$APP" | head -3
grep -n "blackbur'" "$APP" | head -3
grep -n "DEDUP: keep newest" "$APP" | head -1

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
echo "[✓] v5 done. Hard-reload (Ctrl+Shift+R)."
echo "    Sidebar: [All] [Dr. Whitney] [Dr. Blackburn] [Other]"
echo "    - [All] = no filter (highlighted teal by default)"
echo "    - Blackburn matches 'Blackbur' typo too"
echo "    - Duplicate reports collapsed (newest copy kept)"
echo
echo "    Rollback:"
echo "      cp $BACKUP $APP && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
