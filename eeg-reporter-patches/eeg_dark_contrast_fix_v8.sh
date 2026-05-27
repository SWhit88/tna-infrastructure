#!/usr/bin/env bash
# eeg_dark_contrast_fix_v8.sh
# v8 — adds visible "Spectral data unavailable" text + keeps v7's End Date fix.
# Root cause for "no chart": app.py renders <p style="color:#999">Spectral data unavailable.</p>
# when fig.data is empty. Gray on dark = invisible. CSS overrides the inline color.
set -euo pipefail

CSS=~/eeg-reporter/assets/neurochart-theme.css

# Strip prior v1..v8
sed -i '/\/\* Dark mode contrast overrides v[0-9] \*\//,$d' "$CSS"

cat >> "$CSS" <<'CSS_EOF'

/* Dark mode contrast overrides v8 */

/* Filter bar selects */
body[data-theme="dark"] #search-box input,
body[data-theme="dark"] #filter-status .Select-control,
body[data-theme="dark"] #filter-ordering-md .Select-control,
body[data-theme="dark"] #filter-referring-md .Select-control,
body[data-theme="dark"] #filter-year .Select-control,
body[data-theme="dark"] #filter-month .Select-control,
body[data-theme="dark"] #sort-by .Select-control {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}
body[data-theme="dark"] #search-box input::placeholder { color: #4a5a6a !important; }

/* DATE PICKER — nuclear specificity (End Date fix) */
html body[data-theme="dark"] #filter-date-range,
html body[data-theme="dark"] #filter-date-range .DateRangePickerInput,
html body[data-theme="dark"] #filter-date-range .DateRangePickerInput__withBorder,
html body[data-theme="dark"] #filter-date-range .DateInput,
html body[data-theme="dark"] #filter-date-range .DateInput_1,
html body[data-theme="dark"] #filter-date-range .DateInput_2,
html body[data-theme="dark"] #filter-date-range input.DateInput_input,
html body[data-theme="dark"] #filter-date-range input.DateInput_input_1,
html body[data-theme="dark"] #filter-date-range input.DateInput_input_2 {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border-color: #2a4a6f !important;
  -webkit-text-fill-color: #1a2332 !important;
}
html body[data-theme="dark"] #filter-date-range input::placeholder,
html body[data-theme="dark"] #filter-date-range input::-webkit-input-placeholder {
  color: #4a5a6a !important;
  -webkit-text-fill-color: #4a5a6a !important;
  opacity: 1 !important;
}
html body[data-theme="dark"] #filter-date-range .DateRangePickerInput_arrow,
html body[data-theme="dark"] #filter-date-range .DateRangePickerInput_arrow svg {
  color: #1a2332 !important;
  fill: #1a2332 !important;
}

/* SPECTRAL DATA UNAVAILABLE — override inline color:#999 */
/* The fallback <p style="color:#999">Spectral data unavailable.</p> was invisible. */
body[data-theme="dark"] p[style*="color"],
body[data-theme="dark"] p[style*="#999"] {
  color: #b3d0f0 !important;
  background-color: rgba(30, 58, 95, 0.4);
  padding: 12px;
  border-radius: 6px;
  text-align: center;
  font-style: italic;
}
/* Also light mode — make it more obvious there too */
body:not([data-theme="dark"]) p[style*="#999"] {
  background-color: #f0f4f8;
  padding: 12px;
  border-radius: 6px;
  text-align: center;
  border: 1px dashed #c0cdd9;
}

/* Signer dropdown (pattern-match id) */
body[data-theme="dark"] [id*="interpreting_physician"] .Select-control,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-value-label,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-value,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-placeholder,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-input > input {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
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

/* Editor card surfaces */
body[data-theme="dark"] #editor-pane,
body[data-theme="dark"] #editor-content,
body[data-theme="dark"] .editor-card {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
}
body[data-theme="dark"] #editor-pane input,
body[data-theme="dark"] #editor-pane textarea,
body[data-theme="dark"] #editor-content input,
body[data-theme="dark"] #editor-content textarea {
  background-color: #ffffff !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}
body[data-theme="dark"] #editor-pane label,
body[data-theme="dark"] #editor-content label { color: #1a2332 !important; font-weight: 500 !important; }

/* DataTable */
body[data-theme="dark"] .dash-table-container,
body[data-theme="dark"] .dash-spreadsheet,
body[data-theme="dark"] .dash-cell,
body[data-theme="dark"] .dash-header {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
body[data-theme="dark"] .dash-header { background-color: #e3eaf1 !important; font-weight: 600 !important; }
body[data-theme="dark"] table, body[data-theme="dark"] th, body[data-theme="dark"] td {
  background-color: #f7f9fb !important; color: #1a2332 !important; border-color: #c0cdd9 !important;
}
body[data-theme="dark"] th { background-color: #e3eaf1 !important; }

/* Plotly */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plotly,
body[data-theme="dark"] .main-svg { background-color: #ffffff !important; }

/* List cards */
body[data-theme="dark"] [id*="report-item"] { color: #e8f0f8 !important; }
body[data-theme="dark"] #sign-btn { background-color: #0891B2 !important; color: #ffffff !important; }
CSS_EOF

echo "[+] Appended v8 contrast overrides"
echo "    - End Date: nuclear DateInput_1/_2 specificity"
echo "    - 'Spectral data unavailable' now visible (was inline color:#999)"

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
echo "[✓] Hard-reload (Ctrl+Shift+R)."
echo "    - End Date input should now match Start Date"
echo "    - 'Spectral data unavailable.' should appear where blank rects were"
echo "    - Reports WITH spectral data will show actual bar chart (try Anderson, Mary or any older report)"
