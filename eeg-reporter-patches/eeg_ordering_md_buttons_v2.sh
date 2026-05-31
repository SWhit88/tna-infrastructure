#!/usr/bin/env bash
# eeg_ordering_md_buttons_v2.sh
# v2: uses AST node-walking to find the ord_md filter conditional inside update_list,
# regardless of its exact source form. Also prints the actual filter source it found
# before replacing, so we can audit.
#
# All 4 patches (input replacement, callback input, filter logic, button callback)
# are computed in memory and only written if all 4 succeed AND ast.parse passes.
set -euo pipefail

APP=~/eeg-reporter/app.py
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$APP.bak-$ts-pre-ordering-buttons-v2"
cp "$APP" "$BACKUP"
echo "[*] Backup: $BACKUP"

python3 << 'PYEOF'
import re, ast, sys

APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()
orig = src

# ============================================================
# STEP 0: Locate update_list function bounds via AST
# ============================================================
tree = ast.parse(src)
update_list_node = None
for node in ast.walk(tree):
    if isinstance(node, ast.FunctionDef) and node.name == 'update_list':
        update_list_node = node
        break

if not update_list_node:
    print("FATAL: could not find function update_list in app.py", file=sys.stderr)
    sys.exit(1)

print(f"[*] update_list found: lines {update_list_node.lineno}-{update_list_node.end_lineno}")

# ============================================================
# STEP 1: Find ALL If nodes inside update_list that reference 'ord_md'
# ============================================================
class OrdMdFinder(ast.NodeVisitor):
    def __init__(self):
        self.if_nodes = []
    def visit_If(self, node):
        # Check if 'ord_md' is referenced anywhere in the test expression
        for sub in ast.walk(node.test):
            if isinstance(sub, ast.Name) and sub.id == 'ord_md':
                self.if_nodes.append(node)
                break
        # Also recurse to find nested ifs
        self.generic_visit(node)

finder = OrdMdFinder()
finder.visit(update_list_node)

if not finder.if_nodes:
    # Maybe it's a nested if pattern like:
    #   if ord_md:
    #       if ord_md.lower() not in ...:
    #           continue
    # The outer If's test references ord_md. Check that case too.
    print("FATAL: no If node referencing ord_md found in update_list", file=sys.stderr)
    print("Dumping lines around update_list start for manual inspection:", file=sys.stderr)
    lines = src.split('\n')
    for i in range(max(0, update_list_node.lineno-1), min(len(lines), update_list_node.lineno+60)):
        print(f"  {i+1:4d}: {lines[i]}", file=sys.stderr)
    sys.exit(1)

# Use the FIRST (outermost) match — there may be nested ifs but ast.walk gives outer first
target_if = finder.if_nodes[0]
print(f"[*] Found ord_md If at lines {target_if.lineno}-{target_if.end_lineno}")

# Get the source text of that If node + show it
lines = src.split('\n')
filter_src = '\n'.join(lines[target_if.lineno-1 : target_if.end_lineno])
print("[*] Existing ord_md filter source:")
for ln in filter_src.split('\n'):
    print(f"    | {ln}")

# Compute indent of the If statement (col_offset)
indent = ' ' * target_if.col_offset

# ============================================================
# PATCH 1: replace the Ordering MD text input with button group + Store
# ============================================================
ordering_re = re.compile(
    r'dcc\.Input\(\s*id\s*=\s*"filter-ordering-md"[^)]*\)',
    re.DOTALL
)
m = ordering_re.search(src)
if not m:
    print("FATAL: could not find dcc.Input(id=\"filter-ordering-md\", ...)", file=sys.stderr)
    sys.exit(1)

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

# We need to do all string mutations carefully — line numbers from AST refer to ORIGINAL src.
# Strategy: do the filter replacement FIRST (since it uses line numbers), then do the others which use regex.
# But the filter replacement uses .lineno from a tree parsed on the ORIGINAL src, so we must do it before
# any other mutation. So order:
#   (a) Compute filter span in original src — get byte offsets
#   (b) Apply input replacement (regex on src) — track delta? Easier: do filter first.

# Get byte span for the If node using line/col offsets
def line_col_to_offset(text, line, col):
    # line is 1-based, col is 0-based
    cur = 0
    for i, ln in enumerate(text.split('\n'), start=1):
        if i == line:
            return cur + col
        cur += len(ln) + 1  # +1 for \n
    return cur

start_off = line_col_to_offset(src, target_if.lineno, target_if.col_offset)
# end_lineno is the last line of the If; end_col_offset is just past last char
end_off = line_col_to_offset(src, target_if.end_lineno, target_if.end_col_offset)

# Verify we got the right span
extracted = src[start_off:end_off]
print(f"[*] Extracted span ({len(extracted)} chars), preview:")
for ln in extracted.split('\n')[:8]:
    print(f"    > {ln}")

# Build new filter logic
new_filter = f'''# Ordering MD button filter (whitney / blackburn / other)
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

# Replace the If node span with the new filter
src_v1 = src[:start_off] + new_filter + src[end_off:]
print("[+] Patched ord_md filter logic in update_list")

# ============================================================
# PATCH 2: change the update_list callback Input
# ============================================================
old_input = 'Input("filter-ordering-md","value")'
new_input = 'Input("ordering-md-filter","data")'
if old_input not in src_v1:
    # Try with spaces
    old_input2 = 'Input("filter-ordering-md", "value")'
    new_input2 = 'Input("ordering-md-filter", "data")'
    if old_input2 in src_v1:
        src_v1 = src_v1.replace(old_input2, new_input2)
    else:
        print(f"FATAL: cannot find {old_input!r} or {old_input2!r}", file=sys.stderr)
        sys.exit(1)
else:
    src_v1 = src_v1.replace(old_input, new_input)
print("[+] Patched update_list callback Input from filter-ordering-md to ordering-md-filter")

# ============================================================
# PATCH 3: replace dcc.Input for Ordering MD with button group
# ============================================================
m2 = ordering_re.search(src_v1)
if not m2:
    print("FATAL: dcc.Input(id=\"filter-ordering-md\") not found after other patches", file=sys.stderr)
    sys.exit(1)
src_v1 = src_v1[:m2.start()] + input_replacement + src_v1[m2.end():]
print("[+] Replaced Ordering MD input with button group + Store")

# ============================================================
# PATCH 4: add button-state callback before __main__ guard
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

guard_match = re.search(r'\n(if __name__\s*==\s*[\'"]__main__[\'"]:)', src_v1)
if guard_match:
    src_v1 = src_v1[:guard_match.start()] + callback_code + src_v1[guard_match.start():]
    print("[+] Added ordering-md button callback before __main__ guard")
else:
    src_v1 = src_v1.rstrip() + '\n' + callback_code + '\n'
    print("[+] Appended ordering-md button callback to end of file")

# ============================================================
# Final AST validation
# ============================================================
try:
    ast.parse(src_v1)
except SyntaxError as e:
    print(f"FATAL: post-patch SyntaxError: {e}", file=sys.stderr)
    # Dump the area around the error
    err_line = e.lineno or 0
    lines = src_v1.split('\n')
    for i in range(max(0, err_line-5), min(len(lines), err_line+5)):
        marker = ' >>>' if i+1 == err_line else '    '
        print(f"{marker} {i+1:4d}: {lines[i]}", file=sys.stderr)
    sys.exit(2)

open(APP, 'w').write(src_v1)
print("[+] File written successfully")
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
