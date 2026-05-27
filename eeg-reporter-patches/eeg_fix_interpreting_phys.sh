#!/usr/bin/env bash
# Fix: remove "interpreting_physician" from HEADER_FIELDS so it stops being a
# State source for callbacks that depend on edit-* component IDs. The
# interpreting physician is the signer, set from config, never edited per-report.
# This eliminates the client-side Dash ReferenceError that was breaking every
# Save/Sign/Preview button.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
bak="${APP}.bak-${ts}-pre-interp-fix"
cp "$APP" "$bak"
echo "Backup: $bak"

python3 - <<'PY'
import pathlib, re, sys, ast
p = pathlib.Path.home() / "eeg-reporter" / "app.py"
src = p.read_text()

# Match the HEADER_FIELDS block — multi-line list literal
m = re.search(
    r'^HEADER_FIELDS\s*=\s*\[(.*?)\]',
    src, flags=re.MULTILINE | re.DOTALL
)
if not m:
    print("ERROR: HEADER_FIELDS not found", file=sys.stderr)
    sys.exit(2)

block = m.group(0)
inner = m.group(1)

# Parse the list literal safely
try:
    fields = ast.literal_eval("[" + inner + "]")
except Exception as e:
    print(f"ERROR: could not parse HEADER_FIELDS list: {e}", file=sys.stderr)
    sys.exit(3)

if "interpreting_physician" not in fields:
    print("Already absent from HEADER_FIELDS — no change.")
    sys.exit(0)

new_fields = [f for f in fields if f != "interpreting_physician"]
# Rebuild with original indentation style: keep simple repr
new_block = 'HEADER_FIELDS = ' + repr(new_fields).replace("'", '"')

new_src = src[:m.start()] + new_block + src[m.end():]

# Validate
ast.parse(new_src)
p.write_text(new_src)
print("Patched: removed 'interpreting_physician' from HEADER_FIELDS")
print()
# Show new HEADER_FIELDS line
for i, line in enumerate(new_src.splitlines(), 1):
    if line.startswith("HEADER_FIELDS"):
        print(f"{i:5d}: {line}")
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
tail -n 12 ~/eeg-reporter/logs/app.log
