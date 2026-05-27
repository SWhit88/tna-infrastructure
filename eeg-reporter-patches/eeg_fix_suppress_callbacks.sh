#!/usr/bin/env bash
# Fix: IndexError on /_dash-update-component when no report is selected or
# a signed report is selected. Root cause: _SAVE_STATES references edit-*
# component IDs that are conditionally rendered inside show_report().
# Setting suppress_callback_exceptions=True lets Dash dispatch the callback
# even when some State IDs aren't currently in the layout — the function
# body already guards on `if not n or not path: return dash.no_update`.
set -euo pipefail
APP=~/eeg-reporter/app.py
[ -f "$APP" ] || { echo "MISSING: $APP"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
bak="${APP}.bak-${ts}-pre-suppress"
cp "$APP" "$bak"
echo "Backup: $bak"

python3 - <<'PY'
import pathlib, re, sys
p = pathlib.Path.home() / "eeg-reporter" / "app.py"
src = p.read_text()

# Find the Dash app construction. Most common forms:
#   app = Dash(__name__, ...)
#   app = dash.Dash(__name__, ...)
m = re.search(r'^([ \t]*)app\s*=\s*(?:dash\.)?Dash\s*\((.*?)\)\s*$',
              src, flags=re.MULTILINE | re.DOTALL)
if not m:
    print("ERROR: could not locate `app = Dash(...)` constructor", file=sys.stderr)
    sys.exit(2)

indent, args = m.group(1), m.group(2)
if "suppress_callback_exceptions" in args:
    print("Already has suppress_callback_exceptions — no change.")
    sys.exit(0)

# Append the kwarg, preserving original whitespace style as best we can
new_args = args.rstrip()
if new_args.endswith(","):
    new_args += " suppress_callback_exceptions=True"
else:
    new_args += ", suppress_callback_exceptions=True"
new_call = f"{indent}app = Dash({new_args})"

# Reconstruct (if it was dash.Dash, preserve that prefix)
orig = m.group(0)
if "dash.Dash" in orig:
    new_call = new_call.replace("Dash(", "dash.Dash(", 1)

new_src = src[:m.start()] + new_call + src[m.end():]

# Compile-check before writing
import ast
ast.parse(new_src)

p.write_text(new_src)
print("Patched: added suppress_callback_exceptions=True")
print("---")
# Show the constructor line in the patched file
for i, line in enumerate(new_src.splitlines(), 1):
    if "Dash(" in line and "app" in line and "=" in line:
        print(f"{i:5d}: {line}")
        # also show continuation lines
        for j in range(i, min(i+5, len(new_src.splitlines())+1)):
            l = new_src.splitlines()[j-1] if j != i else None
            if l is not None and (l.strip().endswith(")") or "suppress_callback_exceptions" in l):
                print(f"{j:5d}: {l}")
        break
PY

# Restart the reporter
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
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || echo "Not yet responding"
echo
echo "Tail of app.log:"
tail -n 15 ~/eeg-reporter/logs/app.log
