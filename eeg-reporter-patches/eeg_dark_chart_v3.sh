#!/usr/bin/env bash
# eeg_dark_chart_v3.sh
# v3: Target the actual rendered Plotly DOM (.js-plotly-plot / .svg-container / .main-svg)
# Discovery via DOM inspection on 2026-05-31:
#   - There is NO #chart-bandpower id (previous patches missed)
#   - Chart SVGs live at: .js-plotly-plot > .plot-container > .svg-container > svg.main-svg
#   - SVG size 849x240, top:165, parent class "user-select-none svg-container"
#   - js-plotly-tester SVG correctly parked at top:-10000 (ignore)
# Strategy: belt-and-suspenders CSS targeting Plotly's actual generated classes,
#   force bg/text/gridline colors in dark mode only.

set -euo pipefail
cd ~/eeg-reporter

CSS=assets/neurochart-theme.css
JS=assets/theme-toggle.js
ts=$(date +%Y%m%d_%H%M%S)
cp "$CSS" "${CSS}.bak.${ts}"
cp "$JS" "${JS}.bak.${ts}"

# 1) Strip any prior CHART_PDR_DARK_MODE_FIX_v2 + DARK_PLACEHOLDER_FIX_v1 blocks
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/neurochart-theme.css')
s = p.read_text()
# Remove old chart fix blocks (keep DATE_INPUT_DARK_MODE_FIX_v3 alone)
for marker in ('CHART_PDR_DARK_MODE_FIX_v2', 'CHART_PDR_DARK_MODE_FIX_v1',
               'DARK_PLACEHOLDER_FIX_v1', 'CHART_BANDPOWER_DARK',
               'CHART_DARK_MODE_FIX_v3'):
    pat = re.compile(r'/\*\s*BEGIN ' + marker + r'.*?END ' + marker + r'\s*\*/\s*',
                     re.DOTALL)
    s = pat.sub('', s)
p.write_text(s)
print('stripped old chart fix blocks')
PY

# 2) Append v3 dark mode chart CSS targeting real Plotly classes
cat >> "$CSS" <<'CSS_EOF'

/* BEGIN CHART_DARK_MODE_FIX_v3 - 2026-05-31
   Targets ACTUAL rendered Plotly DOM (.js-plotly-plot, .svg-container, .main-svg)
   discovered via runtime DOM inspection. The previous patches targeted #chart-bandpower
   which does not exist in the rendered output. */

/* Force dark background on every Plotly plot container in dark mode */
[data-theme="dark"] .js-plotly-plot,
[data-theme="dark"] .plot-container,
[data-theme="dark"] .svg-container {
  background-color: var(--nc-surface) !important;
}

/* Plot background rects (paper + plotbg) */
[data-theme="dark"] .js-plotly-plot .main-svg .bg {
  fill: var(--nc-surface) !important;
}
[data-theme="dark"] .js-plotly-plot .main-svg .cartesianlayer .bg,
[data-theme="dark"] .js-plotly-plot .main-svg rect.bg {
  fill: var(--nc-surface) !important;
}

/* All text inside any Plotly SVG -> light text in dark mode */
[data-theme="dark"] .js-plotly-plot .main-svg text,
[data-theme="dark"] .js-plotly-plot .main-svg .xtick text,
[data-theme="dark"] .js-plotly-plot .main-svg .ytick text,
[data-theme="dark"] .js-plotly-plot .main-svg .g-gtitle text,
[data-theme="dark"] .js-plotly-plot .main-svg .gtitle,
[data-theme="dark"] .js-plotly-plot .main-svg .legendtext {
  fill: var(--nc-text) !important;
}

/* Gridlines and axis lines -> visible muted color in dark mode */
[data-theme="dark"] .js-plotly-plot .main-svg .gridlayer path,
[data-theme="dark"] .js-plotly-plot .main-svg .xgrid,
[data-theme="dark"] .js-plotly-plot .main-svg .ygrid {
  stroke: var(--nc-border) !important;
  stroke-opacity: 0.6 !important;
}
[data-theme="dark"] .js-plotly-plot .main-svg .xaxis path.domain,
[data-theme="dark"] .js-plotly-plot .main-svg .yaxis path.domain,
[data-theme="dark"] .js-plotly-plot .main-svg .crisp {
  stroke: var(--nc-text-muted) !important;
}
[data-theme="dark"] .js-plotly-plot .main-svg .xtick > path,
[data-theme="dark"] .js-plotly-plot .main-svg .ytick > path {
  stroke: var(--nc-text-muted) !important;
}

/* Sibling containers (header, PDR line) keep their dark surface */
[data-theme="dark"] .dash-graph,
[data-theme="dark"] .dash-graph > div {
  background-color: var(--nc-surface) !important;
}

/* END CHART_DARK_MODE_FIX_v3 */
CSS_EOF

# 3) Bump theme-toggle.js version so cache busts
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/theme-toggle.js')
s = p.read_text()
s2 = re.sub(r"v1\.0\.1[0-9]", "v1.0.15", s)
if s != s2:
    p.write_text(s2)
    print("version bumped to v1.0.15")
else:
    print("warning: no version string matched, no bump applied")
PY

# 4) Also bump the app footer if present
python3 <<'PY'
import re, pathlib
p = pathlib.Path('app.py')
if p.exists():
    s = p.read_text()
    s2 = re.sub(r"EEG Reporter v1\.0\.1[0-9]", "EEG Reporter v1.0.15", s)
    if s != s2:
        p.write_text(s2)
        print("app.py footer version bumped to v1.0.15")
PY

echo "----- restarting eeg-reporter -----"
pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
echo "----- last 20 log lines -----"
tail -n 20 /tmp/eeg-reporter.log || true
echo
echo "v3 chart dark mode applied. Hard refresh the page: Ctrl+Shift+R"
echo "Footer should read: EEG Reporter v1.0.15"
