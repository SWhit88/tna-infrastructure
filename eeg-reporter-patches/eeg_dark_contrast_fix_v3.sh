#!/bin/bash
# v3 dark contrast — targets card annotations + bare inputs + plotly.
# Idempotent: strips any v1/v2/v3 override blocks before re-appending.
set -e
cd ~/eeg-reporter/assets

if [ ! -f neurochart-theme.css ]; then
    echo "FATAL: neurochart-theme.css not found"
    exit 1
fi

sed -i '/\/\* ========== Dark mode contrast overrides v1/,$d' neurochart-theme.css
sed -i '/\/\* ========== Dark mode contrast overrides v2/,$d' neurochart-theme.css
sed -i '/\/\* ========== Dark mode contrast overrides v3/,$d' neurochart-theme.css

cat >> neurochart-theme.css <<'CSS'

/* ========== Dark mode contrast overrides v3 (2026-05-27 17:53) ========== */

body[data-theme="dark"] {
  --nc-bg:          #1c2433;
  --nc-surface:     #2a3548;     /* lifted slightly from v2 so cards stand out */
  --nc-surface-alt: #344056;
  --nc-border:      #45526c;     /* brighter border so cards have visible edge */

  --nc-navy:        #7aa8e0;
  --nc-navy-light:  #9bc0ee;
  --nc-teal:        #3dd3ed;
  --nc-teal-light:  #6ee0f1;
  --nc-text:        #f0f5fb;     /* near-white primary */
  --nc-text-muted:  #b8c3d6;     /* much brighter than before */
}

/* ----- Title + headings ----- */
body[data-theme="dark"] h1 {
  color: var(--nc-teal) !important;
  border-bottom-color: var(--nc-teal) !important;
}
body[data-theme="dark"] h2, body[data-theme="dark"] h3,
body[data-theme="dark"] h4, body[data-theme="dark"] h5,
body[data-theme="dark"] h6 {
  color: #b3d0f0 !important;
}

/* ===== REPORT CARD ANNOTATIONS (the main complaint) ===== */
/* Cards: solid surface, visible border, gentle separation from bg */
body[data-theme="dark"] [id*="report-item"] {
  background: var(--nc-surface) !important;
  background-color: var(--nc-surface) !important;
  border: 1px solid var(--nc-border) !important;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.3) !important;
}
body[data-theme="dark"] [id*="report-item"]:hover {
  background: var(--nc-surface-alt) !important;
}

/* All text inside cards — force readable colors regardless of inline style */
body[data-theme="dark"] [id*="report-item"] > div {
  color: #f0f5fb !important;     /* default text */
}
/* First line = patient name = brightest */
body[data-theme="dark"] [id*="report-item"] > div:nth-child(1) {
  color: #ffffff !important;
  font-weight: 700 !important;
}
/* Second line = recording date */
body[data-theme="dark"] [id*="report-item"] > div:nth-child(2) {
  color: #d4dde9 !important;
}
/* Third line = DOB */
body[data-theme="dark"] [id*="report-item"] > div:nth-child(3) {
  color: #b8c3d6 !important;
}
/* Fourth line = status (DRAFT or FINAL …). The app uses inline color
   #cc6600 / #007700 which are too dark on dark — brighten them. */
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4) {
  color: #ffb84d !important;     /* default DRAFT bright orange */
  font-weight: 700 !important;
}
/* If status text is the signed-green color, repaint brighter green */
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4)[style*="#007700"],
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4)[style*="007700"] {
  color: #5fdf7a !important;
}
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4)[style*="#cc6600"],
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4)[style*="cc6600"] {
  color: #ffb84d !important;
}
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4)[style*="#cc0000"],
body[data-theme="dark"] [id*="report-item"] > div:nth-child(4)[style*="cc0000"] {
  color: #ff7070 !important;
}

/* ===== INPUTS — KILL THE BLAZING WHITE ===== */
/* Match every input, including the dcc.Input default style */
body[data-theme="dark"] input,
body[data-theme="dark"] input[type="text"],
body[data-theme="dark"] input[type="search"],
body[data-theme="dark"] input[type="number"],
body[data-theme="dark"] input[type="date"],
body[data-theme="dark"] textarea {
  background: #2a3548 !important;
  background-color: #2a3548 !important;
  color: #f0f5fb !important;
  border: 1px solid #45526c !important;
  border-radius: 4px !important;
}
body[data-theme="dark"] input::placeholder,
body[data-theme="dark"] textarea::placeholder {
  color: #9aa6bd !important;
  opacity: 1 !important;
}

/* react-select wrappers */
body[data-theme="dark"] .Select,
body[data-theme="dark"] .Select-control,
body[data-theme="dark"] .Select-menu-outer,
body[data-theme="dark"] .Select-menu,
body[data-theme="dark"] .dash-dropdown,
body[data-theme="dark"] .dash-dropdown .Select-control,
body[data-theme="dark"] [class*="control-"],
body[data-theme="dark"] [class*="menu-"],
body[data-theme="dark"] [class*="ValueContainer"],
body[data-theme="dark"] [class*="singleValue"] {
  background: #2a3548 !important;
  background-color: #2a3548 !important;
  color: #f0f5fb !important;
  border-color: #45526c !important;
}
body[data-theme="dark"] .Select-placeholder,
body[data-theme="dark"] [class*="placeholder"] {
  color: #9aa6bd !important;
}
body[data-theme="dark"] .Select-value-label,
body[data-theme="dark"] .Select-value {
  color: #f0f5fb !important;
}
body[data-theme="dark"] .Select-option,
body[data-theme="dark"] [class*="option-"] {
  background: #2a3548 !important;
  color: #f0f5fb !important;
}
body[data-theme="dark"] .Select-option.is-focused,
body[data-theme="dark"] .Select-option:hover {
  background: #344056 !important;
}

/* Date picker */
body[data-theme="dark"] .DateInput,
body[data-theme="dark"] .DateInput_input,
body[data-theme="dark"] .DateRangePickerInput,
body[data-theme="dark"] .DateRangePickerInput__withBorder,
body[data-theme="dark"] .SingleDatePickerInput {
  background: #2a3548 !important;
  background-color: #2a3548 !important;
  color: #f0f5fb !important;
  border-color: #45526c !important;
}
body[data-theme="dark"] .DateInput_input::placeholder {
  color: #9aa6bd !important;
}

/* ===== PLOTLY CHART ===== */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plot-container,
body[data-theme="dark"] .plotly,
body[data-theme="dark"] .main-svg,
body[data-theme="dark"] .svg-container {
  background: #2a3548 !important;
  background-color: #2a3548 !important;
}
/* Force chart inner backgrounds via SVG fill */
body[data-theme="dark"] .js-plotly-plot .bg,
body[data-theme="dark"] .js-plotly-plot .nsewdrag,
body[data-theme="dark"] .js-plotly-plot rect.bg,
body[data-theme="dark"] .js-plotly-plot rect.plotbg {
  fill: #2a3548 !important;
}
/* All chart text */
body[data-theme="dark"] .js-plotly-plot text,
body[data-theme="dark"] .js-plotly-plot .gtitle,
body[data-theme="dark"] .js-plotly-plot .xtitle,
body[data-theme="dark"] .js-plotly-plot .ytitle,
body[data-theme="dark"] .js-plotly-plot .xtick text,
body[data-theme="dark"] .js-plotly-plot .ytick text,
body[data-theme="dark"] .js-plotly-plot .legendtext,
body[data-theme="dark"] .js-plotly-plot .annotation text {
  fill: #f0f5fb !important;
}
/* Grid + axes */
body[data-theme="dark"] .js-plotly-plot .xgrid,
body[data-theme="dark"] .js-plotly-plot .ygrid,
body[data-theme="dark"] .js-plotly-plot .grid path {
  stroke: #45526c !important;
}
body[data-theme="dark"] .js-plotly-plot .xaxis path,
body[data-theme="dark"] .js-plotly-plot .yaxis path,
body[data-theme="dark"] .js-plotly-plot .xaxislayer-above path,
body[data-theme="dark"] .js-plotly-plot .yaxislayer-above path,
body[data-theme="dark"] .js-plotly-plot .crisp {
  stroke: #b8c3d6 !important;
}

/* ===== Tab bar (above chart) ===== */
body[data-theme="dark"] .rc-tabs,
body[data-theme="dark"] .rc-tabs-bar,
body[data-theme="dark"] .rc-tabs-nav,
body[data-theme="dark"] .rc-tabs-nav-list,
body[data-theme="dark"] .rc-tabs-tab,
body[data-theme="dark"] [role="tab"],
body[data-theme="dark"] [role="tablist"] {
  background: #344056 !important;
  background-color: #344056 !important;
  color: #f0f5fb !important;
  border-color: #45526c !important;
}
body[data-theme="dark"] .rc-tabs-tab-active,
body[data-theme="dark"] [role="tab"][aria-selected="true"] {
  background: #2a3548 !important;
  color: #3dd3ed !important;
  border-bottom-color: #3dd3ed !important;
}

/* ===== Catch-all for inline white bg ===== */
body[data-theme="dark"] [style*="#fff"],
body[data-theme="dark"] [style*="#FFF"],
body[data-theme="dark"] [style*="#ffffff"],
body[data-theme="dark"] [style*="#FFFFFF"],
body[data-theme="dark"] [style*="rgb(255, 255, 255)"],
body[data-theme="dark"] [style*="rgb(255,255,255)"] {
  background-color: #2a3548 !important;
}

/* ===== Section labels e.g. "HEADER FIELDS" ===== */
body[data-theme="dark"] [style*="color:#1e3a5f"],
body[data-theme="dark"] [style*="color: #1e3a5f"] {
  color: #b3d0f0 !important;
}

/* Patient field labels ("Patient Name:", "Patient ID:") */
body[data-theme="dark"] label,
body[data-theme="dark"] strong {
  color: #d4dde9 !important;
}

CSS

echo "[+] Appended v3 contrast overrides"
echo

echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true

echo
echo "[✓] Hard-reload (Ctrl+Shift+R)."
