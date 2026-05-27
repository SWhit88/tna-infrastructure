#!/usr/bin/env bash
# Simpler fix: after Sign & Finalize, the success message already shows
# "✓ Signed & finalized." in editor-status. Replace that with a richer
# message that includes a direct "Open Signed PDF" link pointing to
# /pdf/signed/<stem>.pdf. The signed-PDF Flask route already exists at
# line 535. User clicks it → PDF opens in new tab → Ctrl+P prints.
# No state-machine plumbing needed.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
bak="${APP}.bak-${ts}-pre-sign-print-btn"
cp "$APP" "$bak"
echo "Backup: $bak"

python3 - <<'PY'
import pathlib, re, sys, ast
p = pathlib.Path.home() / "eeg-reporter" / "app.py"
src = p.read_text()

# Find the do_sign success return block.
# Original:
#   return (html.Span("✓ Signed & finalized.",
#                     style={"color":"#006600","fontWeight":"bold"}),
#           (trigger or 0) + 1)
#
# New: replace the plain Span with a Div that includes both the success
# message AND a clickable "Open Signed PDF" link.

# Build the new success return string
new_success = '''return (html.Div([
                    html.Span("\u2713 Signed & finalized. ",
                              style={"color":"#006600","fontWeight":"bold"}),
                    html.A("\u2b07 Open Signed PDF",
                           href=f"/pdf/signed/{pdf_signed.name}",
                           target="_blank",
                           style={"marginLeft":"8px","padding":"4px 10px",
                                  "backgroundColor":"#006600","color":"white",
                                  "borderRadius":"3px","textDecoration":"none",
                                  "fontSize":"9pt"}),
                ]),
                (trigger or 0) + 1)'''

# Match the original success return (multiline)
orig_pat = re.compile(
    r'return \(html\.Span\("\u2713 Signed & finalized\.",\s*\n\s*style=\{"color":"#006600","fontWeight":"bold"\}\),\s*\n\s*\(trigger or 0\) \+ 1\)',
    re.DOTALL
)
new_src, n = orig_pat.subn(new_success, src)
if n == 0:
    print("ERROR: do_sign success return not found", file=sys.stderr)
    sys.exit(2)
print(f"Patched do_sign success return to include Open Signed PDF link: {n}")

ast.parse(new_src)
p.write_text(new_src)

# Show patched block
lines = new_src.splitlines()
for i, line in enumerate(lines, 1):
    if "def do_sign" in line:
        start = i
        end = min(len(lines), i + 38)
        print()
        print("=" * 60)
        print("Patched do_sign body:")
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
