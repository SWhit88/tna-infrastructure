#!/usr/bin/env bash
# eeg_dark_contrast_fix_v5.sh
# v5 — targets remaining dark-mode contrast bugs reported after v4:
#   1) End Date input still dark (Start Date is light)
#   2) FILE ANNOTATIONS Dash DataTable white-on-white
#   3) Interpreting MD (Signer) dropdown text invisible
#   4) Header field labels ("Patient Name:" etc.) too dim
#   5) Plotly bar fallback for white-on-white
# Idempotent: strips any prior v1..v5 block before appending.
set -euo pipefail

CSS=~/eeg-reporter/assets/neurochart-theme.css

if [[ ! -f "$CSS" ]]; then
  echo "[!] $CSS not found — run eeg_neurochart_theme_combined.sh first" >&2
  exit 1
fi

# Strip any prior dark-contrast block (v1..v5)
sed -i '/\/\* Dark mode contrast overrides v[0-9] \*\//,$d' "$CSS"

cat >> "$CSS" <<'CSS_EOF'

/* Dark mode contrast overrides v5 */
/* --- Filter bar: light backgrounds with dark text (kept from v4) --- */
body[data-theme="dark"] #search-box input,
body[data-theme="dark"] #filter-status .Select-control,
body[data-theme="dark"] #filter-ordering-md .Select-control,
body[data-theme="dark"] #filter-referring-md .Select-control,
body[data-theme="dark"] #filter-year .Select-control,
body[data-theme="dark"] #filter-month .Select-control,
body[data-theme="dark"] #filter-sort .Select-control {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}
body[data-theme="dark"] #search-box input::placeholder {
  color: #4a5a6a !important;
}

/* --- Date range pickers: BOTH start and end (v5 fix #1) --- */
body[data-theme="dark"] #filter-date-range,
body[data-theme="dark"] #filter-date-range .DateRangePickerInput,
body[data-theme="dark"] #filter-date-range .DateInput,
body[data-theme="dark"] #filter-date-range .DateInput_1,
body[data-theme="dark"] #filter-date-range .DateInput_2,
body[data-theme="dark"] .DateRangePickerInput,
body[data-theme="dark"] .DateInput,
body[data-theme="dark"] .DateInput_input,
body[data-theme="dark"] .DateInput_input_1,
body[data-theme="dark"] .DateInput_input_2 {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border-color: #2a4a6f !important;
}
body[data-theme="dark"] .DateRangePickerInput__arrow,
body[data-theme="dark"] .DateRangePickerInput_arrow {
  color: #1a2332 !important;
}
body[data-theme="dark"] .DateInput_input::placeholder {
  color: #4a5a6a !important;
}

/* --- ALL Select-control text (v5 fix #3: Signer dropdown was light blue on white) --- */
body[data-theme="dark"] .Select-control,
body[data-theme="dark"] .Select-value-label,
body[data-theme="dark"] .Select-value,
body[data-theme="dark"] .Select-placeholder,
body[data-theme="dark"] .Select-input > input,
body[data-theme="dark"] .Select-multi-value-wrapper,
body[data-theme="dark"] .Select-arrow-zone,
body[data-theme="dark"] .Select-arrow {
  color: #1a2332 !important;
}
body[data-theme="dark"] .Select-control {
  background-color: #f0f4f8 !important;
  border-color: #2a4a6f !important;
}
body[data-theme="dark"] .Select-menu-outer,
body[data-theme="dark"] .Select-menu,
body[data-theme="dark"] .Select-option {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
}
body[data-theme="dark"] .Select-option.is-focused,
body[data-theme="dark"] .Select-option:hover {
  background-color: #d4e1ef !important;
  color: #1a2332 !important;
}

/* --- Editor card surface stays light in dark mode (kept from v4) --- */
body[data-theme="dark"] .editor-card,
body[data-theme="dark"] .report-card,
body[data-theme="dark"] div[id^="report-card"],
body[data-theme="dark"] #editor-pane,
body[data-theme="dark"] #editor-content {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
}

/* --- Editor input fields --- */
body[data-theme="dark"] #editor-pane input[type="text"],
body[data-theme="dark"] #editor-pane input[type="date"],
body[data-theme="dark"] #editor-pane textarea,
body[data-theme="dark"] #editor-content input[type="text"],
body[data-theme="dark"] #editor-content input[type="date"],
body[data-theme="dark"] #editor-content textarea {
  background-color: #ffffff !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}

/* --- v5 fix #4: Header field labels brightened --- */
body[data-theme="dark"] #editor-pane label,
body[data-theme="dark"] #editor-content label,
body[data-theme="dark"] .editor-card label,
body[data-theme="dark"] label {
  color: #b3d0f0 !important;
}

/* --- v5 fix #2: Dash DataTable (FILE ANNOTATIONS) — light bg, dark text --- */
body[data-theme="dark"] .dash-table-container,
body[data-theme="dark"] .dash-spreadsheet,
body[data-theme="dark"] .dash-spreadsheet-container,
body[data-theme="dark"] .dash-spreadsheet-inner,
body[data-theme="dark"] .dash-cell,
body[data-theme="dark"] .dash-cell-value,
body[data-theme="dark"] .dash-header,
body[data-theme="dark"] .dash-header-cell-value,
body[data-theme="dark"] .dash-filter,
body[data-theme="dark"] .dash-spreadsheet td,
body[data-theme="dark"] .dash-spreadsheet th {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
body[data-theme="dark"] .dash-header,
body[data-theme="dark"] .dash-spreadsheet th {
  background-color: #e3eaf1 !important;
  font-weight: 600 !important;
}
/* Plain HTML tables (annotations fallback) */
body[data-theme="dark"] table,
body[data-theme="dark"] th,
body[data-theme="dark"] td {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
body[data-theme="dark"] th {
  background-color: #e3eaf1 !important;
}

/* --- Plotly chart stays on light panel (kept from v4 — confirmed working) --- */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plotly,
body[data-theme="dark"] .main-svg {
  background-color: #ffffff !important;
}
body[data-theme="dark"] .js-plotly-plot .plotly .modebar {
  background-color: #ffffff !important;
}
/* v5 fix #5: Plotly bar fill fallback (if any traces inherited dark) */
body[data-theme="dark"] .js-plotly-plot .plotly .bars .point path,
body[data-theme="dark"] .js-plotly-plot .plotly .barlayer .point path {
  stroke: #1e3a5f !important;
}

/* --- Two-column list cards keep their accent borders but readable text --- */
body[data-theme="dark"] [id*="report-item"] {
  color: #e8f0f8 !important;
}

/* --- Sign button stays teal in dark mode --- */
body[data-theme="dark"] #sign-btn,
body[data-theme="dark"] button#sign-btn {
  background-color: #0891B2 !important;
  color: #ffffff !important;
}
CSS_EOF

echo "[+] Appended v5 contrast overrides"
echo
echo "[*] Restarting eeg-reporter..."
if systemctl --user is-active --quiet eeg-reporter 2>/dev/null; then
  systemctl --user restart eeg-reporter
elif systemctl is-active --quiet eeg-reporter 2>/dev/null; then
  sudo systemctl restart eeg-reporter
else
  pkill -f 'python.*app.py' 2>/dev/null || true
  sleep 1
  (cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &)
fi
sleep 3
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
echo
echo "[✓] Hard-reload (Ctrl+Shift+R), stay in dark mode."
