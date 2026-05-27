#!/usr/bin/env bash
# Fix: after Sign & Finalize, the right pane still shows the draft view
# with no Download button. User must manually re-click the report from
# the list to access the signed PDF. Fix by updating current-report-path
# to the new signed JSON path and bumping list-refresh-trigger so the
# list re-renders and the report-item points to signed/.
#
# do_sign already returns (editor_status, list_refresh_trigger).
# After this patch it ALSO updates current-report-path.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
bak="${APP}.bak-${ts}-pre-sign-redirect"
cp "$APP" "$bak"
echo "Backup: $bak"

python3 - <<'PY'
import pathlib, re, sys, ast
p = pathlib.Path.home() / "eeg-reporter" / "app.py"
src = p.read_text()

# ============================================================
# Step 1: Add Output("current-report-path", "data", allow_duplicate=True)
# to do_sign's decorator
# ============================================================
sign_dec = re.search(
    r'(@app\.callback\(\s*\n\s*Output\("editor-status",\s*"children",\s*allow_duplicate=True\),\s*\n\s*Output\("list-refresh-trigger",\s*"data"\),)',
    src
)
if not sign_dec:
    print("ERROR: do_sign decorator not found", file=sys.stderr)
    sys.exit(2)

new_dec = sign_dec.group(1) + '\n    Output("current-report-path", "data", allow_duplicate=True),'
src = src[:sign_dec.start()] + new_dec + src[sign_dec.end():]
print("Added Output(current-report-path) to do_sign")

# ============================================================
# Step 2: Update do_sign return statements
# Currently returns 2-tuple. Now needs 3-tuple with the signed path.
# ============================================================
# Success return: (html.Span("✓ Signed..."), (trigger or 0) + 1)
#   -> (html.Span("✓ Signed..."), (trigger or 0) + 1, str(json_signed))
success_pat = re.compile(
    r'return \(html\.Span\("\u2713 Signed & finalized\.",\s*\n\s*style=\{"color":"#006600","fontWeight":"bold"\}\),\s*\n\s*\(trigger or 0\) \+ 1\)',
    re.DOTALL
)
def success_repl(m):
    return ('return (html.Span("\u2713 Signed & finalized.",\n'
            '                          style={"color":"#006600","fontWeight":"bold"}),\n'
            '                (trigger or 0) + 1,\n'
            '                str(json_signed))')
src, n_success = success_pat.subn(success_repl, src)
print(f"Patched do_sign success return: {n_success}")

# Failure return: (html.Span(f"✗ Sign error: {e}"), dash.no_update)
#   -> (html.Span(f"✗ Sign error: {e}"), dash.no_update, dash.no_update)
fail_pat = re.compile(
    r'return html\.Span\(f"\u2717 Sign error: \{e\}",\s*style=\{"color":"#cc0000"\}\),\s*dash\.no_update'
)
def fail_repl(m):
    return ('return html.Span(f"\u2717 Sign error: {e}", style={"color":"#cc0000"}), '
            'dash.no_update, dash.no_update')
src, n_fail = fail_pat.subn(fail_repl, src)
print(f"Patched do_sign failure return: {n_fail}")

# Also the early guard: `if not n or not path: return dash.no_update, dash.no_update`
# Needs to return 3-tuple now
guard_pat = re.compile(
    r'(def do_sign\(n, path, trigger, \*values\):\s*\n\s*if not n or not path:\s*\n\s*return dash\.no_update, dash\.no_update)'
)
def guard_repl(m):
    return m.group(1).replace(
        "return dash.no_update, dash.no_update",
        "return dash.no_update, dash.no_update, dash.no_update"
    )
src, n_guard = guard_pat.subn(guard_repl, src)
print(f"Patched do_sign guard return: {n_guard}")

# ============================================================
# Validate
# ============================================================
ast.parse(src)
p.write_text(src)

# Show do_sign as patched
lines = src.splitlines()
for i, line in enumerate(lines, 1):
    if "def do_sign" in line:
        start = max(1, i - 12)
        end = min(len(lines), i + 32)
        print()
        print("=" * 60)
        print("Patched do_sign (decorator + body):")
        print("=" * 60)
        for j in range(start, end + 1):
            print(f"{j:5d}: {lines[j-1]}")
        break
PY

echo
echo "Restarting reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
cd ~/eeg-reporter
nohup python3 main.py > logs/app.log 2>&1 &
echo "PID: $!"
sleep 3
echo
echo "Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/
echo
echo "Tail of app.log:"
tail -n 15 ~/eeg-reporter/logs/app.log
