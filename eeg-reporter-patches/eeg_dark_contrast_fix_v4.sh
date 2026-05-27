#!/bin/bash
# v4: Selective inversion in dark mode.
#   - Chart area (Plotly) → light/white as in light mode
#   - Report cards (annotations) → light/white as in light mode
#   - Filter inputs (search, status, ref MD, ord MD, year, month, sort,
#     date range) → soft light-gray bg with dark text
#   - Everything else (page bg, headings, editor pane labels, etc.) stays dark
#
# Idempotent: strips any prior v1-v4 override blocks first.
set -e
cd ~/eeg-reporter/assets

if [ ! -f neurochart-theme.css ]; then
    echo "FATAL: neurochart-theme.css not found"; exit 1
fi

for v in v1 v2 v3 v4; do
    sed -i "/\/\* ========== Dark mode contrast overrides $v/,\$d" neurochart-theme.css
done

cat >> neurochart-theme.css <<'CSS'

/* ========== Dark mode contrast overrides v4 (2026-05-27 18:01) ========== */
/* Strategy: dark page, but invert specific zones to light surfaces:
     (a) chart area
     (b) report cards / annotations
     (c) filter inputs (soft gray bg + dark text)
*/

body[data-theme="dark"] {
  --nc-bg:          #1c2433;
  --nc-surface:     #2a3548;
  --nc-surface-alt: #344056;
  --nc-border:      #45526c;
  --nc-navy:        #7aa8e0;
  --nc-navy-light:  #9bc0ee;
  --nc-teal:        #3dd3ed;
  --nc-teal-light:  #6ee0f1;
  --nc-text:        #f0f5fb;
  --nc-text-muted:  #b8c3d6;
}

/* ----- Headings still dark-mode bright ----- */
body[data-theme="dark"] h1 {
  color: var(--nc-teal) !important;
  border-bottom-color: var(--nc-teal) !important;
}
body[data-theme="dark"] h2, body[data-theme="dark"] h3,
body[data-theme="dark"] h4, body[data-theme="dark"] h5,
body[data-theme="dark"] h6 {
  color: #b3d0f0 !important;
}

/* ===========================================================
   (A) REPORT CARDS = LIGHT MODE STYLE
   =========================================================== */
body[data-theme="dark"] [id*="report-item"] {
  background: #ffffff !important;
  background-color: #ffffff !important;
  border: 1px solid #d6dde6 !important;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.25) !important;
  color: #1a2332 !important;
}
body[data-theme="dark"] [id*="report-item"]:hover {
  background: #f7f9fc !important;
  background-color: #f7f9fc !important;
}
/* Force descendant text back to dark */
body[data-theme="dark"] [id*="report-item"] > div {
  color: #1a2332 !important;
}
body[data-theme="dark"] [id*="report-item"] > div:nth-child(1) {
  color: #1a2332 !important;
  font-weight: 700 !important;
}
body[data-theme="dark"] [id*="report-item"] > div:nth-child(2) {
  color: #555555 !important;
}
body[data-theme="dark"] [id*="report-item"] > div:nth-child(3) {
  color: #777777 !important;
}
/* Status line keeps its inline color (cc6600 orange / 007700 green) */

/* ===========================================================
   (B) PLOTLY CHART = LIGHT MODE STYLE
   =========================================================== */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plot-container,
body[data-theme="dark"] .plotly,
body[data-theme="dark"] .main-svg,
body[data-theme="dark"] .svg-container {
  background: #ffffff !important;
  background-color: #ffffff !important;
}
body[data-theme="dark"] .js-plotly-plot .bg,
body[data-theme="dark"] .js-plotly-plot .nsewdrag,
body[data-theme="dark"] .js-plotly-plot rect.bg,
body[data-theme="dark"] .js-plotly-plot rect.plotbg {
  fill: #ffffff !important;
}
body[data-theme="dark"] .js-plotly-plot text,
body[data-theme="dark"] .js-plotly-plot .gtitle,
body[data-theme="dark"] .js-plotly-plot .xtitle,
body[data-theme="dark"] .js-plotly-plot .ytitle,
body[data-theme="dark"] .js-plotly-plot .xtick text,
body[data-theme="dark"] .js-plotly-plot .ytick text,
body[data-theme="dark"] .js-plotly-plot .legendtext,
body[data-theme="dark"] .js-plotly-plot .annotation text {
  fill: #1a2332 !important;
}
body[data-theme="dark"] .js-plotly-plot .xgrid,
body[data-theme="dark"] .js-plotly-plot .ygrid,
body[data-theme="dark"] .js-plotly-plot .grid path {
  stroke: #e0e6ed !important;
}
body[data-theme="dark"] .js-plotly-plot .xaxis path,
body[data-theme="dark"] .js-plotly-plot .yaxis path,
body[data-theme="dark"] .js-plotly-plot .xaxislayer-above path,
body[data-theme="dark"] .js-plotly-plot .yaxislayer-above path,
body[data-theme="dark"] .js-plotly-plot .crisp {
  stroke: #555555 !important;
}

/* ===========================================================
   (C) FILTER INPUTS = LIGHT-GRAY BG + DARK TEXT
   Target only the filter controls, not all inputs in the app.
   The filter controls are inside the left "Reports" panel and have known IDs:
     search-box, filter-status, filter-referring-md, filter-ordering-md,
     filter-year, filter-month, sort-by, filter-date-range
   =========================================================== */

/* Bare inputs (search-box, ref MD, ord MD) — these are <input type="text"> */
body[data-theme="dark"] #search-box input,
body[data-theme="dark"] #search-box,
body[data-theme="dark"] #filter-referring-md input,
body[data-theme="dark"] #filter-referring-md,
body[data-theme="dark"] #filter-ordering-md input,
body[data-theme="dark"] #filter-ordering-md {
  background: #e8edf3 !important;
  background-color: #e8edf3 !important;
  color: #1a2332 !important;
  border: 1px solid #c0c8d4 !important;
}
body[data-theme="dark"] #search-box input::placeholder,
body[data-theme="dark"] #filter-referring-md input::placeholder,
body[data-theme="dark"] #filter-ordering-md input::placeholder,
body[data-theme="dark"] #search-box::placeholder,
body[data-theme="dark"] #filter-referring-md::placeholder,
body[data-theme="dark"] #filter-ordering-md::placeholder {
  color: #6b7a90 !important;
  opacity: 1 !important;
}

/* react-select dropdowns (status, year, month, sort) */
body[data-theme="dark"] #filter-status .Select-control,
body[data-theme="dark"] #filter-year .Select-control,
body[data-theme="dark"] #filter-month .Select-control,
body[data-theme="dark"] #sort-by .Select-control,
body[data-theme="dark"] #filter-status [class*="control-"],
body[data-theme="dark"] #filter-year [class*="control-"],
body[data-theme="dark"] #filter-month [class*="control-"],
body[data-theme="dark"] #sort-by [class*="control-"] {
  background: #e8edf3 !important;
  background-color: #e8edf3 !important;
  color: #1a2332 !important;
  border: 1px solid #c0c8d4 !important;
}
body[data-theme="dark"] #filter-status .Select-value-label,
body[data-theme="dark"] #filter-year .Select-value-label,
body[data-theme="dark"] #filter-month .Select-value-label,
body[data-theme="dark"] #sort-by .Select-value-label,
body[data-theme="dark"] #filter-status [class*="singleValue"],
body[data-theme="dark"] #filter-year [class*="singleValue"],
body[data-theme="dark"] #filter-month [class*="singleValue"],
body[data-theme="dark"] #sort-by [class*="singleValue"],
body[data-theme="dark"] #filter-status .Select-placeholder,
body[data-theme="dark"] #filter-year .Select-placeholder,
body[data-theme="dark"] #filter-month .Select-placeholder,
body[data-theme="dark"] #sort-by .Select-placeholder {
  color: #1a2332 !important;
}
/* Dropdown OPEN menu */
body[data-theme="dark"] #filter-status .Select-menu-outer,
body[data-theme="dark"] #filter-year .Select-menu-outer,
body[data-theme="dark"] #filter-month .Select-menu-outer,
body[data-theme="dark"] #sort-by .Select-menu-outer {
  background: #ffffff !important;
  color: #1a2332 !important;
  border: 1px solid #c0c8d4 !important;
}
body[data-theme="dark"] #filter-status .Select-option,
body[data-theme="dark"] #filter-year .Select-option,
body[data-theme="dark"] #filter-month .Select-option,
body[data-theme="dark"] #sort-by .Select-option {
  background: #ffffff !important;
  color: #1a2332 !important;
}
body[data-theme="dark"] #filter-status .Select-option.is-focused,
body[data-theme="dark"] #filter-year .Select-option.is-focused,
body[data-theme="dark"] #filter-month .Select-option.is-focused,
body[data-theme="dark"] #sort-by .Select-option.is-focused,
body[data-theme="dark"] #filter-status .Select-option:hover,
body[data-theme="dark"] #filter-year .Select-option:hover,
body[data-theme="dark"] #filter-month .Select-option:hover,
body[data-theme="dark"] #sort-by .Select-option:hover {
  background: #e8edf3 !important;
}

/* Date range picker */
body[data-theme="dark"] #filter-date-range,
body[data-theme="dark"] #filter-date-range .DateInput,
body[data-theme="dark"] #filter-date-range .DateInput_input,
body[data-theme="dark"] #filter-date-range .DateRangePickerInput,
body[data-theme="dark"] #filter-date-range .DateRangePickerInput__withBorder {
  background: #e8edf3 !important;
  background-color: #e8edf3 !important;
  color: #1a2332 !important;
  border-color: #c0c8d4 !important;
}
body[data-theme="dark"] #filter-date-range .DateInput_input::placeholder {
  color: #6b7a90 !important;
  opacity: 1 !important;
}

CSS

echo "[+] Appended v4 selective-inversion overrides"

echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
echo
echo "[✓] Hard-reload (Ctrl+Shift+R), stay in dark mode."
