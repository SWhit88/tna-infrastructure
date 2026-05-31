#!/usr/bin/env bash
# eeg_ordering_md_buttons_v3.sh
# v3: targets the actual variable used in the filter — `ord_q` (precomputed lowercase),
# not `ord_md`. Also removes the now-unused `ord_q = (ord_md or '').strip().lower()` line
# since the button-driven `ord_md` is a token ('whitney'/'blackburn'/'other'/None), not free text.
set -euo pipefail

APP=~/eeg-reporter/app.py
[[ -f "$APP" ]] || { echo "[!] $APP missing"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BACKUP="$APP.bak-$ts-pre-ordering-buttons-v3"
cp "$APP" "$BACKUP"
echo "[*] Backup: $BACKUP"

python3 << 'PYEOF'
import re, ast, sys

APP = '/home/leige/eeg-reporter/app.py'
src = open(APP).read()

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
# STEP 1a: Find the `ord_q = (ord_md or '').strip().lower()` assignment to remove
# ============================================================
ord_q_assign_node = None
for node in ast.walk(update_list_node):
    if isinstance(node, ast.Assign):
        if (len(node.targets) == 1
            and isinstance(node.targets[0], ast.Name)
            and node.targets[0].id == 'ord_q'):
            ord_q_assign_node = node
            break

if not ord_q_assign_node:
    print("[!] Warning: ord_q assignment not found (might already be removed)")
else:
    print(f"[*] Found ord_q assignment at line {ord_q_assign_node.lineno}")

# ============================================================
# STEP 1b: Find the If node whose test references `ord_q` (the filter conditional)
# ============================================================
class OrdQFinder(ast.NodeVisitor):
    def __init__(self):
        self.if_nodes = []
    def visit_If(self, node):
        for sub in ast.walk(node.test):
            if isinstance(sub, ast.Name) and sub.id == 'ord_q':
                self.if_nodes.append(node)
                break
        self.generic_visit(node)

finder = OrdQFinder()
finder.visit(update_list_node)

if not finder.if_nodes:
    print("FATAL: no If node referencing ord_q found in update_list", file=sys.stderr)
    sys.exit(1)

target_if = finder.if_nodes[0]
print(f"[*] Found ord_q filter If at lines {target_if.lineno}-{target_if.end_lineno}")

lines = src.split('\n')
filter_src_preview = '\n'.join(lines[target_if.lineno-1 : target_if.end_lineno])
print("[*] Existing filter source to replace:")
for ln in filter_src_preview.split('\n'):
    print(f"    | {ln}")

# ============================================================
# Compute byte offsets for both replacements (from ORIGINAL src)
# ============================================================
def line_col_to_offset(text, line, col):
    cur = 0
    for i, ln in enumerate(text.split('\n'), start=1):
        if i == line:
            return cur + col
        cur += len(ln) + 1
    return cur

filter_start = line_col_to_offset(src, target_if.lineno, target_if.col_offset)
filter_end   = line_col_to_offset(src, target_if.end_lineno, target_if.end_col_offset)

if ord_q_assign_node:
    assign_start = line_col_to_offset(src, ord_q_assign_node.lineno, ord_q_assign_node.col_offset)
    assign_end   = line_col_to_offset(src, ord_q_assign_node.end_lineno, ord_q_assign_node.end_col_offset)
    # Extend assign_end to swallow the trailing newline so we don't leave a blank line
    if assign_end < len(src) and src[assign_end] == '\n':
        assign_end += 1
else:
    assign_start = assign_end = None

# Indent for the new filter block (same column as the original If)
indent = ' ' * target_if.col_offset

new_filter = f'''# Ordering MD button filter (whitney / blackburn / other)
{indent}_ord_str = (str(rpt.get('ordering_physician','') or '') + ' ' + str(((findings.get('pnt_meta',{{}}) or {{}}).get('physician','') or '') if isinstance(findings, dict) else '')).lower()
{indent}if ord_md == 'whitney':
{indent}    if 'whitney' not in _ord_str:
{indent}        continue
{indent}elif ord_md == 'blackburn':
{indent}    if 'blackburn' not in _ord_str:
{indent}        continue
{indent}elif ord_md == 'other':
{indent}    if 'whitney' in _ord_str or 'blackburn' in _ord_str:
{indent}        continue'''

# ============================================================
# Apply replacements in REVERSE byte order so earlier offsets don't shift
# ============================================================
# 1. Replace the If filter (later in file)
src_v1 = src[:filter_start] + new_filter + src[filter_end:]

# 2. Remove the ord_q assignment (earlier in file)
if assign_start is not None:
    src_v1 = src_v1[:assign_start] + src_v1[assign_end + (len(new_filter) - (filter_end - filter_start)):] \
        if False else src_v1  # noop guard, real logic below

# Simpler: do filter first, then re-locate the assign in the new src by string match
if ord_q_assign_node:
    assign_text = "ord_q = (ord_md or '').strip().lower()"
    if assign_text in src_v1:
        # Remove the line including its leading whitespace and trailing newline
        idx = src_v1.find(assign_text)
        # back up to start of line
        ls = src_v1.rfind('\n', 0, idx) + 1
        # forward to end of line including \n
        le = src_v1.find('\n', idx)
        if le == -1:
            le = len(src_v1)
        else:
            le += 1
        src_v1 = src_v1[:ls] + src_v1[le:]
        print("[+] Removed unused ord_q assignment line")
    else:
        print("[!] ord_q assignment text not found by string match — leaving it (harmless)")

print("[+] Patched ord_q filter logic")

# ============================================================
# PATCH 2: change the update_list callback Input
# ============================================================
old_inputs = [
    'Input("filter-ordering-md","value")',
    'Input("filter-ordering-md", "value")',
    "Input('filter-ordering-md','value')",
    "Input('filter-ordering-md', 'value')",
]
patched_input = False
for old in old_inputs:
    if old in src_v1:
        new = old.replace('filter-ordering-md', 'ordering-md-filter').replace('value', 'data')
        src_v1 = src_v1.replace(old, new)
        patched_input = True
        print(f"[+] Patched callback Input: {old} -> {new}")
        break
if not patched_input:
    print("FATAL: cannot find Input(\"filter-ordering-md\",\"value\") in any form", file=sys.stderr)
    sys.exit(1)

# ============================================================
# PATCH 3: replace dcc.Input for Ordering MD with button group
# ============================================================
ordering_re = re.compile(
    r'dcc\.Input\(\s*id\s*=\s*"filter-ordering-md"[^)]*\)',
    re.DOTALL
)
m2 = ordering_re.search(src_v1)
if not m2:
    print("FATAL: dcc.Input(id=\"filter-ordering-md\") not found", file=sys.stderr)
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
    err_line = e.lineno or 0
    lines_v = src_v1.split('\n')
    for i in range(max(0, err_line-5), min(len(lines_v), err_line+5)):
        marker = ' >>>' if i+1 == err_line else '    '
        print(f"{marker} {i+1:4d}: {lines_v[i]}", file=sys.stderr)
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
