#!/bin/bash
# Dash UI fixes for EEG reporter:
#   1. Ordering MD filter was comparing against interpreting_physician (copy-paste bug)
#   2. Free-text search didn't include ordering/referring physician in haystack
#   3. Interpreting MD field becomes a dropdown (Whitney/Blackburn)
set -e
cd ~/eeg-reporter
cp app.py app.py.bak-$(date +%Y%m%d-%H%M%S)
cp config.py config.py.bak-$(date +%Y%m%d-%H%M%S)

python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/app.py"
src = p.read_text()

# ---------- Patch 1: Ordering MD filter actually compares against ordering_physician ----------
old1 = '''        if ord_q and ord_q not in (rpt.get('interpreting_physician','') or '').lower():
            continue'''
new1 = '''        if ord_q and ord_q not in (rpt.get('ordering_physician','') or '').lower() \\
                    and ord_q not in ((findings.get('pnt_meta',{}) or {}).get('physician','') or '').lower():
            continue'''
if old1 not in src:
    print("ERROR: Patch 1 target not found")
    raise SystemExit(1)
src = src.replace(old1, new1)

# ---------- Patch 2: Search haystack includes ordering + referring + pnt_meta physician ----------
old2 = '''            haystack = ' '.join([rpt.get('patient_name',''), rpt.get('patient_id',''), rpt.get('patient_dob',''), rpt.get('recording_date',''), rpt.get('interpreting_physician',''), rpt.get('status','')]).lower()'''
new2 = '''            pnt_phys = (findings.get('pnt_meta',{}) or {}).get('physician','') if isinstance(findings, dict) else ''
            haystack = ' '.join([
                rpt.get('patient_name',''), rpt.get('patient_id',''), rpt.get('patient_dob',''),
                rpt.get('recording_date',''),
                rpt.get('interpreting_physician',''),
                rpt.get('ordering_physician','') or '',
                rpt.get('referring_physician','') or '',
                pnt_phys or '',
                rpt.get('status','')
            ]).lower()'''
if old2 not in src:
    print("ERROR: Patch 2 target not found")
    raise SystemExit(1)
src = src.replace(old2, new2)

# ---------- Patch 3: Interpreting MD becomes a dropdown ----------
# Find the _input_row call for interpreting_physician and replace with a dropdown
old3 = '''        _input_row("Interpreting MD (Signer)", "interpreting_physician", rpt.get("interpreting_physician","")),'''
new3 = '''        # Interpreting MD is restricted to the two reading neurologists
        html.Div([
            html.Label("Interpreting MD (Signer)", style={"fontWeight":"bold","display":"block","marginBottom":"4px"}),
            dcc.Dropdown(
                id={"type":"field","name":"interpreting_physician"},
                options=[
                    {"label":"Stan Whitney, M.D.",      "value":"Stan Whitney, M.D."},
                    {"label":"Richard Blackburn, M.D.", "value":"Richard Blackburn, M.D."},
                ],
                value=(rpt.get("interpreting_physician","") or "Stan Whitney, M.D."),
                clearable=False,
                style={"width":"320px","marginBottom":"8px"}
            ),
        ], style={"marginBottom":"8px"}),'''
if old3 not in src:
    print("ERROR: Patch 3 target not found")
    raise SystemExit(1)
src = src.replace(old3, new3)

p.write_text(src)
print("All 3 app.py patches applied")
PYFIX

# Also normalize the default signer in config.py so new reports get a recognized value
python3 <<'PYFIX2'
from pathlib import Path
p = Path.home() / "eeg-reporter/config.py"
src = p.read_text()
old = 'INTERPRETING_PHYSICIAN = "S. Whitney, MD"'
new = 'INTERPRETING_PHYSICIAN = "Stan Whitney, M.D."  # default; per-report dropdown overrides'
if old not in src:
    print("WARN: config.py default not at expected value — skipping (manual review)")
else:
    p.write_text(src.replace(old, new))
    print("config.py default signer normalized")
PYFIX2

python3 -c "import ast; ast.parse(open('app.py').read()); print('app.py SYNTAX OK')"
python3 -c "import ast; ast.parse(open('config.py').read()); print('config.py SYNTAX OK')"

# Restart Dash app to pick up changes
tmux kill-session -t eeg-reporter 2>/dev/null || true
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
tail -8 logs/app.log

echo ""
echo "=== Smoke test: how many reports contain 'blackburn' in any MD field? ==="
python3 <<'PY'
import json, glob
hits = 0
total = 0
for f in glob.glob('/home/leige/eeg-reporter/reports/*.json'):
    try:
        d = json.load(open(f))
        total += 1
        rpt = d.get('report',{}) or {}
        findings = d.get('findings',{}) or {}
        pnt = findings.get('pnt_meta',{}) or {}
        text = ' '.join([
            rpt.get('ordering_physician','') or '',
            rpt.get('referring_physician','') or '',
            pnt.get('physician','') or '',
        ]).lower()
        if 'blackburn' in text:
            hits += 1
    except: pass
print(f"Blackburn matches: {hits} of {total} total reports")
PY
