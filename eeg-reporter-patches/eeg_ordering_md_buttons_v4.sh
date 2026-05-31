#!/usr/bin/env bash
# eeg_ordering_md_buttons_v4.sh
# v4: AST-locates the dcc.Input(id="filter-ordering-md", ...) call so we get the
# EXACT span of the entire call expression — fixing v3's regex bug that stopped at
# the first ')' inside the style dict and left trailing kwargs dangling.
#
# All node locations are collected on the ORIGINAL src; mutations are applied in
# REVERSE byte order (highest offset first) so earlier offsets remain valid.
set -euo pipefail

APP=~/eeg-reporter/app.py
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$APP.bak-$ts-pre-ordering-buttons-v4"
cp "$APP" "$BACKUP"
echo "[*] Backup: $BACKUP"

python3 << 'PYEOF'
import re, ast, sys

APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()

def line_col_to_offset(text, line, col):
    cur = 0
    for i, ln in enumerate(text.split('\n'), start=1):
        if i == line:
            return cur + col
        cur += len(ln) + 1
    return cur

def node_span(text, node):
    return (line_col_to_offset(text, node.lineno, node.col_offset),
            line_col_to_offset(text, node.end_lineno, node.end_col_offset))

# ============================================================
# Parse
# ============================================================
tree = ast.parse(src)

# Locate update_list
update_list_node = None
for n in ast.walk(tree):
    if isinstance(n, ast.FunctionDef) and n.name == 'update_list':
        update_list_node = n
        break
if not update_list_node:
    print("FATAL: update_list not found", file=sys.stderr); sys.exit(1)

# ----- Find dcc.Input(...) call with id="filter-ordering-md" -----
ordering_input_node = None
for n in ast.walk(tree):
    if isinstance(n, ast.Call):
        f = n.func
        is_dcc_input = (
            isinstance(f, ast.Attribute) and f.attr == 'Input'
            and isinstance(f.value, ast.Name) and f.value.id == 'dcc'
        )
        if not is_dcc_input:
            continue
        # Look for id kwarg with value "filter-ordering-md"
        for kw in n.keywords:
            if kw.arg == 'id' and isinstance(kw.value, ast.Constant) and kw.value.value == 'filter-ordering-md':
                ordering_input_node = n
                break
        if ordering_input_node:
            break

if not ordering_input_node:
    print("FATAL: dcc.Input(id=\"filter-ordering-md\", ...) not found via AST", file=sys.stderr)
    sys.exit(1)

inp_start, inp_end = node_span(src, ordering_input_node)
print(f"[*] dcc.Input(filter-ordering-md) spans bytes {inp_start}-{inp_end}, lines {ordering_input_node.lineno}-{ordering_input_node.end_lineno}")
print("[*] Existing input source:")
for ln in src[inp_start:inp_end].split('\n'):
    print(f"    | {ln}")

# ----- Find the If node that tests `ord_q` -----
ord_q_if = None
for n in ast.walk(update_list_node):
    if isinstance(n, ast.If):
        for sub in ast.walk(n.test):
            if isinstance(sub, ast.Name) and sub.id == 'ord_q':
                ord_q_if = n
                break
        if ord_q_if:
            break
if not ord_q_if:
    print("FATAL: ord_q If not found", file=sys.stderr); sys.exit(1)

if_start, if_end = node_span(src, ord_q_if)
print(f"[*] ord_q filter If spans lines {ord_q_if.lineno}-{ord_q_if.end_lineno}")

# ----- Find ord_q assignment node -----
ord_q_assign = None
for n in ast.walk(update_list_node):
    if isinstance(n, ast.Assign) and len(n.targets) == 1:
        t = n.targets[0]
        if isinstance(t, ast.Name) and t.id == 'ord_q':
            ord_q_assign = n
            break
if ord_q_assign:
    assign_start, assign_end = node_span(src, ord_q_assign)
    # extend through trailing newline
    while assign_end < len(src) and src[assign_end] != '\n':
        assign_end += 1
    if assign_end < len(src) and src[assign_end] == '\n':
        assign_end += 1
    # also back up to start of indentation on that line
    ls = src.rfind('\n', 0, assign_start) + 1
    assign_start = ls
    print(f"[*] ord_q assignment spans bytes {assign_start}-{assign_end} (line {ord_q_assign.lineno})")
else:
    assign_start = assign_end = None

# ----- Find Input("filter-ordering-md","value") inside callback decorator -----
# Walk the whole tree for Call nodes whose func is Name 'Input' with first two args matching
callback_input_node = None
for n in ast.walk(tree):
    if isinstance(n, ast.Call):
        f = n.func
        if isinstance(f, ast.Name) and f.id == 'Input' and len(n.args) >= 2:
            a0, a1 = n.args[0], n.args[1]
            if (isinstance(a0, ast.Constant) and a0.value == 'filter-ordering-md'
                and isinstance(a1, ast.Constant) and a1.value == 'value'):
                callback_input_node = n
                break
if not callback_input_node:
    print("FATAL: Input(\"filter-ordering-md\",\"value\") not found in any callback", file=sys.stderr)
    sys.exit(1)
cb_start, cb_end = node_span(src, callback_input_node)
print(f"[*] Callback Input spans bytes {cb_start}-{cb_end} (line {callback_input_node.lineno})")

# ============================================================
# Build replacement strings
# ============================================================
indent_if = ' ' * ord_q_if.col_offset
indent_inp = ' ' * ordering_input_node.col_offset

new_filter = f'''# Ordering MD button filter (whitney / blackburn / other)
{indent_if}_ord_str = ((rpt.get('ordering_physician','') or '') + ' ' + (((findings.get('pnt_meta',{{}}) or {{}}).get('physician','') or '') if isinstance(findings, dict) else '')).lower()
{indent_if}if ord_md == 'whitney':
{indent_if}    if 'whitney' not in _ord_str:
{indent_if}        continue
{indent_if}elif ord_md == 'blackburn':
{indent_if}    if 'blackburn' not in _ord_str:
{indent_if}        continue
{indent_if}elif ord_md == 'other':
{indent_if}    if 'whitney' in _ord_str or 'blackburn' in _ord_str:
{indent_if}        continue'''

# The dcc.Input we're replacing sits inside an outer container that's already indented.
# The new replacement is an html.Div(...) — single expression — that takes the same
# slot as the dcc.Input expression. We do NOT add extra indent at the start of the
# replacement string because the indent before the original expression is already in src.
input_replacement = '''html.Div([
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

new_callback_input = 'Input("ordering-md-filter", "data")'

# ============================================================
# Apply mutations in REVERSE byte order so earlier offsets stay valid
# ============================================================
# Collect all (start, end, replacement) tuples and sort by start descending
mutations = []
mutations.append((if_start, if_end, new_filter))
mutations.append((inp_start, inp_end, input_replacement))
mutations.append((cb_start, cb_end, new_callback_input))
if assign_start is not None:
    mutations.append((assign_start, assign_end, ''))

# Sanity: no overlaps
mutations.sort(key=lambda t: t[0])
for i in range(len(mutations) - 1):
    if mutations[i][1] > mutations[i+1][0]:
        print(f"FATAL: overlapping mutations: {mutations[i]} vs {mutations[i+1]}", file=sys.stderr)
        sys.exit(1)

# Apply highest-offset first
mutations.sort(key=lambda t: t[0], reverse=True)
new_src = src
for start, end, repl in mutations:
    new_src = new_src[:start] + repl + new_src[end:]

# ============================================================
# Append button-toggle callback before __main__ guard
# ============================================================
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
    new_val = current
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

guard_match = re.search(r'\n(if __name__\s*==\s*[\'"]__main__[\'"]:)', new_src)
if guard_match:
    new_src = new_src[:guard_match.start()] + callback_code + new_src[guard_match.start():]
    print("[+] Added ordering-md button callback before __main__ guard")
else:
    new_src = new_src.rstrip() + '\n' + callback_code + '\n'
    print("[+] Appended ordering-md button callback to end of file")

# ============================================================
# Final AST validation
# ============================================================
try:
    ast.parse(new_src)
except SyntaxError as e:
    print(f"FATAL: post-patch SyntaxError: {e}", file=sys.stderr)
    err_line = e.lineno or 0
    lines_v = new_src.split('\n')
    for i in range(max(0, err_line-8), min(len(lines_v), err_line+8)):
        marker = ' >>>' if i+1 == err_line else '    '
        print(f"{marker} {i+1:4d}: {lines_v[i]}", file=sys.stderr)
    sys.exit(2)

open(APP, 'w').write(new_src)
print("[+] File written successfully")
print(f"[+] All 4 patches applied: ord_q assign removed, filter rewired, input -> buttons, callback Input -> Store, button-toggle callback added")
PYEOF

rc=$?
if [[ $rc -ne 0 ]]; then
  echo "[!] Python patch failed (rc=$rc). Restoring from backup."
  cp "$BACKUP" "$APP"
  exit $rc
fi

echo
echo "[*] Verify critical anchors still present:"
grep -n "HEADER_FIELDS = " "$APP" | head -1
grep -n "ALL_EDITS = " "$APP" | head -1
grep -n "_SAVE_STATES = " "$APP" | head -1
grep -n "ordering-md-filter" "$APP" | head -3
grep -n "btn-md-whitney" "$APP" | head -3
grep -n "_ord_str" "$APP" | head -3

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
echo "    [Dr. Whitney] [Dr. Blackburn] [Other]  ← click to filter"
echo
echo "    If anything looks broken, rollback with:"
echo "      cp $BACKUP $APP && pkill -f 'python.*app.py'; sleep 2; cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &"
