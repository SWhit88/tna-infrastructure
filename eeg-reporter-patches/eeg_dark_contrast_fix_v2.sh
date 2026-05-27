#!/bin/bash
# v2 dark contrast fix — much more aggressive.
# Problems from screenshot:
#  - Filter inputs (search, status, MD, year/month, sort) are bright WHITE
#    in dark mode — my catch-all for inline #fff didn't match.
#  - Patient name + HEADER FIELDS heading too dim (--nc-navy still wrong here)
#  - Tab bar above graph unreadable
#  - Plotly chart fully invisible (no axis/text styling)
#  - Sort dropdown selected value invisible
#
# Strategy: wildcard input/select dark-bg rule + explicit Plotly overrides +
# brighter text color across the board.
#
# Idempotent — strips previous v1/v2 override blocks before re-appending.
set -e
cd ~/eeg-reporter/assets

if [ ! -f neurochart-theme.css ]; then
    echo "FATAL: neurochart-theme.css not found"
    exit 1
fi

# Strip previous override blocks (v1 and v2 if present)
sed -i '/\/\* ========== Dark mode contrast overrides v1/,$d' neurochart-theme.css
sed -i '/\/\* ========== Dark mode contrast overrides v2/,$d' neurochart-theme.css

cat >> neurochart-theme.css <<'CSS'

/* ========== Dark mode contrast overrides v2 (2026-05-27) ========== */

body[data-theme="dark"] {
  /* Softer body + surfaces */
  --nc-bg:          #1c2433;
  --nc-surface:     #232d40;
  --nc-surface-alt: #2c3850;
  --nc-border:      #3a4660;

  /* Brighter accents */
  --nc-navy:        #7aa8e0;
  --nc-navy-light:  #9bc0ee;
  --nc-teal:        #3dd3ed;
  --nc-teal-light:  #6ee0f1;
  --nc-text:        #eef3fa;
  --nc-text-muted:  #a8b5cc;
}

/* ----- Title + headings ----- */
body[data-theme="dark"] h1 {
  color: var(--nc-teal) !important;
  border-bottom-color: var(--nc-teal) !important;
}
body[data-theme="dark"] h2,
body[data-theme="dark"] h3,
body[data-theme="dark"] h4,
body[data-theme="dark"] h5,
body[data-theme="dark"] h6 {
  color: #9bc0ee !important;
}

/* ----- ALL inputs / selects / dropdowns — kill the bright white panels ----- */
body[data-theme="dark"] input,
body[data-theme="dark"] textarea,
body[data-theme="dark"] select,
body[data-theme="dark"] .Select,
body[data-theme="dark"] .Select-control,
body[data-theme="dark"] .Select-menu,
body[data-theme="dark"] .Select-menu-outer,
body[data-theme="dark"] .dash-dropdown,
body[data-theme="dark"] .dash-dropdown .Select-control,
body[data-theme="dark"] .dash-dropdown .Select-menu-outer,
body[data-theme="dark"] .VirtualizedSelect,
body[data-theme="dark"] .VirtualizedSelectOption {
  background: var(--nc-surface) !important;
  background-color: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}

/* Force the inner divs of react-select too — these often override .Select-control */
body[data-theme="dark"] .Select > div,
body[data-theme="dark"] .Select > div > div,
body[data-theme="dark"] .Select-control > div,
body[data-theme="dark"] [class*="control-"],
body[data-theme="dark"] [class*="menu-"],
body[data-theme="dark"] [class*="singleValue"],
body[data-theme="dark"] [class*="placeholder"],
body[data-theme="dark"] [class*="indicator"],
body[data-theme="dark"] [class*="ValueContainer"] {
  background: var(--nc-surface) !important;
  background-color: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}

/* Placeholder text */
body[data-theme="dark"] input::placeholder,
body[data-theme="dark"] textarea::placeholder,
body[data-theme="dark"] .Select-placeholder,
body[data-theme="dark"] [class*="placeholder"] {
  color: #8a99b3 !important;
  opacity: 1 !important;
}

/* Selected value in dropdown */
body[data-theme="dark"] .Select-value,
body[data-theme="dark"] .Select-value-label,
body[data-theme="dark"] [class*="singleValue"] {
  color: var(--nc-text) !important;
}

/* Dropdown arrow + clear icon */
body[data-theme="dark"] .Select-arrow,
body[data-theme="dark"] .Select-arrow-zone,
body[data-theme="dark"] .Select-clear,
body[data-theme="dark"] [class*="indicatorContainer"] svg {
  color: var(--nc-text-muted) !important;
  fill: var(--nc-text-muted) !important;
}

/* Dropdown OPEN menu options */
body[data-theme="dark"] .Select-option,
body[data-theme="dark"] [class*="option-"] {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
}
body[data-theme="dark"] .Select-option.is-focused,
body[data-theme="dark"] .Select-option:hover,
body[data-theme="dark"] [class*="option-"]:hover {
  background: var(--nc-surface-alt) !important;
}

/* ----- Date range picker ----- */
body[data-theme="dark"] .DateInput,
body[data-theme="dark"] .DateInput_input,
body[data-theme="dark"] .DateInput_input__focused,
body[data-theme="dark"] .DateRangePickerInput,
body[data-theme="dark"] .DateRangePickerInput__withBorder,
body[data-theme="dark"] .SingleDatePickerInput {
  background: var(--nc-surface) !important;
  background-color: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}
body[data-theme="dark"] .DateInput_input::placeholder {
  color: #8a99b3 !important;
  opacity: 1 !important;
}

/* ----- Tab bar (the light strip above the chart) ----- */
body[data-theme="dark"] .tab,
body[data-theme="dark"] .tab-container,
body[data-theme="dark"] .dash-tab,
body[data-theme="dark"] .dash-tabs,
body[data-theme="dark"] .rc-tabs,
body[data-theme="dark"] .rc-tabs-bar,
body[data-theme="dark"] .rc-tabs-nav,
body[data-theme="dark"] .rc-tabs-nav-list,
body[data-theme="dark"] .rc-tabs-tab,
body[data-theme="dark"] [role="tab"],
body[data-theme="dark"] [role="tablist"] {
  background: var(--nc-surface-alt) !important;
  background-color: var(--nc-surface-alt) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}
body[data-theme="dark"] .rc-tabs-tab-active,
body[data-theme="dark"] [role="tab"][aria-selected="true"] {
  background: var(--nc-surface) !important;
  color: var(--nc-teal) !important;
  border-bottom-color: var(--nc-teal) !important;
}

/* ----- Plotly chart ----- */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plot-container,
body[data-theme="dark"] .plotly,
body[data-theme="dark"] .main-svg,
body[data-theme="dark"] .svg-container {
  background: var(--nc-surface) !important;
}
/* Plot inner bg */
body[data-theme="dark"] .js-plotly-plot .bg,
body[data-theme="dark"] .js-plotly-plot .nsewdrag,
body[data-theme="dark"] .js-plotly-plot .plotbg {
  fill: var(--nc-surface) !important;
}
/* Plot text — axis labels, tick labels, titles, legends */
body[data-theme="dark"] .js-plotly-plot text,
body[data-theme="dark"] .js-plotly-plot .xtitle,
body[data-theme="dark"] .js-plotly-plot .ytitle,
body[data-theme="dark"] .js-plotly-plot .gtitle,
body[data-theme="dark"] .js-plotly-plot .xtick text,
body[data-theme="dark"] .js-plotly-plot .ytick text,
body[data-theme="dark"] .js-plotly-plot .legendtext,
body[data-theme="dark"] .js-plotly-plot .annotation text {
  fill: var(--nc-text) !important;
}
/* Axis + grid lines */
body[data-theme="dark"] .js-plotly-plot .xgrid,
body[data-theme="dark"] .js-plotly-plot .ygrid {
  stroke: var(--nc-border) !important;
}
body[data-theme="dark"] .js-plotly-plot .xaxis path,
body[data-theme="dark"] .js-plotly-plot .yaxis path,
body[data-theme="dark"] .js-plotly-plot .xaxislayer-above path,
body[data-theme="dark"] .js-plotly-plot .yaxislayer-above path {
  stroke: var(--nc-text-muted) !important;
}

/* ----- Catch-all for any element with explicit white bg ----- */
body[data-theme="dark"] [style*="#fff"],
body[data-theme="dark"] [style*="#FFF"],
body[data-theme="dark"] [style*="white"],
body[data-theme="dark"] [style*="#ffffff"],
body[data-theme="dark"] [style*="#FFFFFF"],
body[data-theme="dark"] [style*="rgb(255, 255, 255)"],
body[data-theme="dark"] [style*="rgb(255,255,255)"] {
  background-color: var(--nc-surface) !important;
}
/* But keep text-color white where it was set on text (override above is bg only) */

/* ----- Report cards in dark mode ----- */
body[data-theme="dark"] [id*="report-item"] {
  background: var(--nc-surface) !important;
  background-color: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}
body[data-theme="dark"] [id*="report-item"]:hover {
  background: var(--nc-surface-alt) !important;
}
body[data-theme="dark"] [id*="report-item"] * {
  color: var(--nc-text) !important;
}

/* ----- Patient name banner (top of right pane) ----- */
/* Common pattern: a large bold patient name element. Force readable color. */
body[data-theme="dark"] #patient-name,
body[data-theme="dark"] .patient-name,
body[data-theme="dark"] [id*="patient-name"],
body[data-theme="dark"] [class*="patient-name"] {
  color: var(--nc-teal) !important;
}

CSS

echo "[+] Appended v2 contrast overrides"

echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
curl -sS -o /dev/null -w "CSS HTTP %{http_code}\n" http://127.0.0.1:8060/assets/neurochart-theme.css || true

echo
echo "[✓] Hard-reload (Ctrl+Shift+R) and check dark mode."
