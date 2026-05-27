#!/usr/bin/env bash
# Fix: signed reports throw "No such file or directory" because the JSON
# was moved from reports/ to reports/signed/ at sign time. Add a small
# helper `_resolve_report_path(path)` that returns the existing path
# (trying signed/ as fallback), and route the four file-reading callbacks
# (show_report, save_draft, save_then_preview, do_sign) through it.
#
# Also: save_then_preview must build href against the resolved path, not
# the cached one, so the PDF route gets the right name.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
bak="${APP}.bak-${ts}-pre-signed-lookup"
cp "$APP" "$bak"
echo "Backup: $bak"

python3 - <<'PY'
import pathlib, re, sys, ast
p = pathlib.Path.home() / "eeg-reporter" / "app.py"
src = p.read_text()

# 1. Insert helper function right after the ALL_EDITS definition
helper = '''

def _resolve_report_path(path):
    """Return the actual filesystem path for a report JSON, checking signed/
    as a fallback when the draft file no longer exists. Returns Path object.
    Raises FileNotFoundError if neither exists.
    """
    from pathlib import Path as _P
    pth = _P(path)
    if pth.exists():
        return pth
    # try the signed/ subdir alongside the draft path
    signed_pth = pth.parent / "signed" / pth.name
    if signed_pth.exists():
        return signed_pth
    raise FileNotFoundError(f"Report not found in drafts or signed/: {pth.name}")
'''

m = re.search(r'^ALL_EDITS\s*=.*?$', src, flags=re.MULTILINE)
if not m:
    print("ERROR: ALL_EDITS line not found", file=sys.stderr)
    sys.exit(2)

if "_resolve_report_path" in src:
    print("Helper already present — skipping helper insertion.")
else:
    insert_at = m.end()
    src = src[:insert_at] + helper + src[insert_at:]
    print("Inserted _resolve_report_path helper.")

# 2. Patch the four read sites: data = _j.loads(Path(path).read_text())
#    and data = _j.loads(pth.read_text())  where pth = Path(path)
#
# Common patterns in app.py:
#   pth = Path(path); data = _j.loads(pth.read_text())
#   data = _j.loads(Path(idx).read_text())

patches = 0

# Pattern A: `pth = Path(path)` followed by usage. Replace with resolve.
pattern_a = re.compile(r'(\n\s+)pth\s*=\s*Path\(path\)\b')
def repl_a(m):
    return f"{m.group(1)}pth = _resolve_report_path(path)"
src, n = pattern_a.subn(repl_a, src)
patches += n
print(f"Patched {n} occurrences of `pth = Path(path)`")

# Pattern B: `data = _j.loads(Path(idx).read_text())`
pattern_b = re.compile(r'data\s*=\s*_j\.loads\(\s*Path\(idx\)\.read_text\(\)\s*\)')
def repl_b(m):
    return "data = _j.loads(_resolve_report_path(idx).read_text())"
src, n = pattern_b.subn(repl_b, src)
patches += n
print(f"Patched {n} occurrences of `Path(idx).read_text()`")

# Also: in show_report, after reading data, we should also update
# `idx` so the rest of the function (which builds Download href using
# Path(idx).stem) points to the correct resolved path. But since
# Path(idx).stem only depends on the filename (not the directory), and
# Path(...).stem strips just the extension, the stem is the same whether
# the file lives in reports/ or reports/signed/. So no further edits needed
# for the href generation.

# Validate
ast.parse(src)
p.write_text(src)
print(f"\nTotal patches applied: {patches}")
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
tail -n 12 ~/eeg-reporter/logs/app.log
