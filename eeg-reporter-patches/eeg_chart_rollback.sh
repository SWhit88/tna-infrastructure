#!/usr/bin/env bash
# eeg_chart_rollback.sh
# Roll back all the v4-v7 dark-mode chart Plotly hacks.
# Goal: restore a working light mode (the original state before dark-mode work)
# while keeping the rest of the dark mode CSS that DOES work (date picker, PDR,
# placeholders, etc.). Just strips the chart-specific JS that was clobbering things.

set -euo pipefail
cd ~/eeg-reporter

ts=$(date +%Y%m%d_%H%M%S)
cp assets/theme-toggle.js          "assets/theme-toggle.js.bak.${ts}"
cp assets/neurochart-theme.css     "assets/neurochart-theme.css.bak.${ts}"

echo "===== state before rollback ====="
echo "theme-toggle.js backups available:"
ls -la assets/theme-toggle.js.bak.* 2>/dev/null | tail -10
echo
echo "neurochart-theme.css backups available:"
ls -la assets/neurochart-theme.css.bak.* 2>/dev/null | tail -10

# 1) Strip every PLOTLY_BG_FORCE_v* block from theme-toggle.js
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/theme-toggle.js')
s = p.read_text()
orig = s
pat = re.compile(r'/\*\s*BEGIN PLOTLY_BG_FORCE.*?END PLOTLY_BG_FORCE\S*\s*\*/\s*', re.DOTALL)
s = pat.sub('', s)
if s != orig:
    p.write_text(s)
    print('stripped PLOTLY_BG_FORCE block(s) from theme-toggle.js')
else:
    print('no PLOTLY_BG_FORCE block found (already clean)')
PY

# 2) Strip the chart-specific CSS blocks added in v3-v5 from neurochart-theme.css
#    KEEP everything else (date picker fix, PDR fix, placeholder fix - those work)
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/neurochart-theme.css')
s = p.read_text()
orig = s

# Remove all chart fix blocks (any version) but preserve the things that DO work
for marker in ('CHART_PDR_DARK_MODE_FIX_v2', 'CHART_PDR_DARK_MODE_FIX_v1',
               'CHART_DARK_MODE_FIX_v3', 'CHART_DARK_MODE_FIX_v4',
               'CHART_BANDPOWER_DARK'):
    pat = re.compile(r'/\*\s*BEGIN ' + marker + r'.*?END ' + marker + r'\s*\*/\s*', re.DOTALL)
    s = pat.sub('', s)

# Also remove any standalone rules that hit .js-plotly-plot / .main-svg / rect.bg
# (defensive — leftovers from earlier patches)
suspect_pat = re.compile(
    r'(?:body)?\s*\[data-theme="dark"\][^{}]*(?:js-plotly-plot|main-svg|svg-container|plot-container|rect\.bg|\.bg\b|bglayer)[^{}]*\{[^}]*\}\s*',
    re.IGNORECASE
)
removed = suspect_pat.findall(s)
if removed:
    print('removing', len(removed), 'leftover plotly-targeting CSS rule(s):')
    for r in removed[:5]:
        print('  ', r.strip()[:120].replace('\n',' '))
s = suspect_pat.sub('', s)

if s != orig:
    p.write_text(s)
    print('cleaned neurochart-theme.css')
else:
    print('no plotly CSS to remove')
PY

# 3) Version bump so cache busts and we know rollback loaded
python3 <<'PY'
import re, pathlib
for fn in ('assets/theme-toggle.js', 'app.py'):
    p = pathlib.Path(fn)
    if not p.exists(): continue
    s = p.read_text()
    s2 = re.sub(r"v1\.0\.1[0-9]", "v1.0.20", s)
    if s != s2:
        p.write_text(s2)
        print(f"{fn} -> v1.0.20")
PY

echo
echo "===== restarting eeg-reporter ====="
pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
echo "----- last 10 log lines -----"
tail -n 10 /tmp/eeg-reporter.log
echo
echo "Rollback applied. Footer should now read EEG Reporter v1.0.20"
echo "Light mode chart should now render normally."
echo "Dark mode chart will be back to broken (white rectangle) — accepted state."
echo
echo "If anything looks wrong, the original files are at:"
echo "  ~/eeg-reporter/assets/theme-toggle.js.bak.${ts}"
echo "  ~/eeg-reporter/assets/neurochart-theme.css.bak.${ts}"
