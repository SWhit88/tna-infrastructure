#!/bin/bash
# Splits the EEG Reporter sidebar into two columns:
#   LEFT  = Drafts (unsigned), newest first
#   RIGHT = Finalized (signed), newest first
# Pure layout/callback change — no data model changes, no PDF/Sign logic touched.
set -e
cd ~/eeg-reporter

TS=$(date +%Y%m%d-%H%M%S)
cp app.py app.py.bak-${TS}-pre-two-column
echo "[*] Backup: app.py.bak-${TS}-pre-two-column"

python3 <<'PY'
import re, sys, ast
from pathlib import Path

p = Path("app.py")
src = p.read_text()

# ----------------------------------------------------------------------
# 1. Locate the existing report-list builder.
#    Heuristic: a function or callback that returns the children of the
#    sidebar component (usually id="report-list" or similar). We patch by
#    finding the Output that targets the list container and rewriting the
#    function body to produce a two-column layout.
# ----------------------------------------------------------------------

# Find Output("report-list", "children") or similar
m_out = re.search(r'Output\(\s*["\']([\w\-]+)["\']\s*,\s*["\']children["\']\s*\)', src)
if not m_out:
    print("FATAL: could not find an Output(..., 'children') for the report list", file=sys.stderr)
    sys.exit(2)
list_id = m_out.group(1)
print(f"[*] Detected report-list Output id: {list_id}")

# Find the function that owns this Output. Strategy: look for the @app.callback
# block whose Output matches, then capture the next `def` body.
cb_pat = re.compile(
    r'(@app\.callback\([^)]*Output\(\s*["\']' + re.escape(list_id) + r'["\']\s*,\s*["\']children["\']\s*\)[\s\S]*?\)\s*\ndef\s+(\w+)\s*\(([^)]*)\)\s*:\s*\n)',
    re.MULTILINE,
)
m_cb = cb_pat.search(src)
if not m_cb:
    print("FATAL: could not find the callback that returns children for the list", file=sys.stderr)
    sys.exit(3)
fn_name = m_cb.group(2)
print(f"[*] Detected report-list callback: {fn_name}()")

# Find end of function body (next top-level def/class/@ or EOF)
fn_start = m_cb.start()
fn_body_start = m_cb.end()
tail = src[fn_body_start:]
m_next = re.search(r'\n(?=@app\.|def \w|class \w|app\.layout\s*=|if __name__)', tail)
fn_end = fn_body_start + (m_next.start() if m_next else len(tail))
print(f"[*] Callback span: {fn_start}..{fn_end} ({fn_end-fn_start} chars)")

# ----------------------------------------------------------------------
# 2. Replace the entire callback with a two-column version.
#    We keep the original signature args by re-using m_cb.group(1) header.
# ----------------------------------------------------------------------

orig_decorator_and_def = m_cb.group(1)

# New body — two columns side by side
new_body = '''    """
    Render the sidebar as TWO columns:
      LEFT  = Drafts (unsigned), newest first
      RIGHT = Finalized (signed), newest first
    """
    import os as _os, json as _j
    from pathlib import Path as _P
    from datetime import datetime as _dt

    reports_dir = _P("reports")
    items = []
    for jf in reports_dir.glob("*.json"):
        try:
            d = _j.loads(jf.read_text())
        except Exception:
            continue
        items.append((jf, d))

    def _mtime(t):
        try:
            return t[0].stat().st_mtime
        except Exception:
            return 0.0

    items.sort(key=_mtime, reverse=True)  # newest first

    drafts = []
    signed = []
    for jf, d in items:
        is_signed = bool(d.get("signed_by")) or d.get("status") == "signed"
        (signed if is_signed else drafts).append((jf, d))

    def _card(jf, d, signed_flag):
        name = d.get("patient_name") or d.get("patient", {}).get("name") or jf.stem
        rec_date = d.get("recording_date") or ""
        dob = d.get("patient_dob") or d.get("patient", {}).get("dob") or ""
        status_line = ""
        if signed_flag:
            signer = d.get("signed_by") or "Stan Whitney, M.D."
            status_line = html.Div(
                f"FINAL — Electronically signed by {signer}",
                style={"color": "#006600", "fontSize": "0.85em", "marginTop": "4px"},
            )
        else:
            status_line = html.Div(
                "DRAFT",
                style={"color": "#cc6600", "fontSize": "0.85em", "marginTop": "4px", "fontWeight": "600"},
            )
        klass = "report-card signed" if signed_flag else "report-card draft"
        return html.Div(
            [
                html.Div(name, style={"fontWeight": "700"}),
                html.Div(rec_date, style={"fontSize": "0.85em", "color": "#444"}),
                html.Div(dob, style={"fontSize": "0.8em", "color": "#666"}),
                status_line,
            ],
            id={"type": "report-item", "index": str(jf)},
            n_clicks=0,
            className=klass,
            style={
                "padding": "10px 12px",
                "marginBottom": "8px",
                "background": "#fff",
                "borderLeft": "4px solid " + ("#006600" if signed_flag else "#1e3a5f"),
                "borderRadius": "4px",
                "cursor": "pointer",
                "boxShadow": "0 1px 2px rgba(0,0,0,0.06)",
            },
        )

    left_col = html.Div(
        [
            html.H4("Drafts (Unsigned)", style={"margin": "0 0 8px 0", "color": "#1e3a5f"}),
            html.Div(f"{len(drafts)} report(s)", style={"fontSize": "0.8em", "color": "#6b7a90", "marginBottom": "8px"}),
            *[_card(jf, d, False) for jf, d in drafts],
        ],
        style={"flex": "1", "minWidth": "0", "paddingRight": "8px"},
    )

    right_col = html.Div(
        [
            html.H4("Finalized", style={"margin": "0 0 8px 0", "color": "#006600"}),
            html.Div(f"{len(signed)} report(s)", style={"fontSize": "0.8em", "color": "#6b7a90", "marginBottom": "8px"}),
            *[_card(jf, d, True) for jf, d in signed],
        ],
        style={"flex": "1", "minWidth": "0", "paddingLeft": "8px", "borderLeft": "1px solid #d6dde6"},
    )

    return html.Div(
        [left_col, right_col],
        style={"display": "flex", "flexDirection": "row", "gap": "8px", "width": "100%"},
    )
'''

new_src = src[:fn_start] + orig_decorator_and_def + new_body + src[fn_end:]

# ----------------------------------------------------------------------
# 3. AST-parse to make sure we didn't break anything
# ----------------------------------------------------------------------
try:
    ast.parse(new_src)
except SyntaxError as e:
    print(f"FATAL: AST parse failed after patch: {e}", file=sys.stderr)
    sys.exit(4)

p.write_text(new_src)
print(f"[+] Patched {fn_name}() to render two columns (drafts | finalized)")
print(f"[+] Total file size: {len(new_src)} chars")
PY

echo
echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

echo
echo "[*] Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
echo
echo "[*] Tail of app.log (last 15 lines):"
tail -n 15 ~/eeg-reporter/logs/app.log
echo
echo "[✓] Done. Hard-reload the dashboard (Ctrl+Shift+R)."
