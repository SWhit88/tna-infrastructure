#!/usr/bin/env bash
# eeg_dark_contrast_fix_v6.sh
# v6 — based on actual app.py inspection:
#   - Chart: forces font.color on Plotly via clientside callback (axis text was invisible)
#   - Signer dropdown: targets pattern-match ID {"name":"interpreting_physician","type":"field"}
#   - Date picker: simpler, scoped to #filter-date-range only
# Idempotent: strips any prior v1..v6 block before appending.
set -euo pipefail

CSS=~/eeg-reporter/assets/neurochart-theme.css
JS=~/eeg-reporter/assets/theme-toggle.js

if [[ ! -f "$CSS" ]]; then
  echo "[!] $CSS not found — run eeg_neurochart_theme_combined.sh first" >&2
  exit 1
fi

# Strip prior dark-contrast blocks (v1..v6)
sed -i '/\/\* Dark mode contrast overrides v[0-9] \*\//,$d' "$CSS"

cat >> "$CSS" <<'CSS_EOF'

/* Dark mode contrast overrides v6 */
/* === Filter bar (top, search + filters) — light bg, dark text === */
body[data-theme="dark"] #search-box input,
body[data-theme="dark"] #filter-status .Select-control,
body[data-theme="dark"] #filter-ordering-md .Select-control,
body[data-theme="dark"] #filter-referring-md .Select-control,
body[data-theme="dark"] #filter-year .Select-control,
body[data-theme="dark"] #filter-month .Select-control,
body[data-theme="dark"] #sort-by .Select-control,
body[data-theme="dark"] #filter-sort .Select-control {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}
body[data-theme="dark"] #search-box input::placeholder {
  color: #4a5a6a !important;
}

/* === DatePickerRange (Start + End) — scoped to parent === */
body[data-theme="dark"] #filter-date-range,
body[data-theme="dark"] #filter-date-range *,
body[data-theme="dark"] #filter-date-range .DateRangePickerInput,
body[data-theme="dark"] #filter-date-range .DateInput,
body[data-theme="dark"] #filter-date-range .DateInput_input {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border-color: #2a4a6f !important;
}
body[data-theme="dark"] #filter-date-range .DateInput_input::placeholder,
body[data-theme="dark"] #filter-date-range .DateRangePickerInput_arrow {
  color: #4a5a6a !important;
}

/* === Signer dropdown (pattern-match id) === */
/* Dash serializes pattern IDs as: id='{"name":"interpreting_physician","type":"field"}' */
body[data-theme="dark"] [id*="interpreting_physician"],
body[data-theme="dark"] [id*="interpreting_physician"] .Select-control,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-value-label,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-value,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-placeholder,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-input > input,
body[data-theme="dark"] [id*="interpreting_physician"] .Select-arrow {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border-color: #2a4a6f !important;
}
/* Dropdown menu portal (renders outside the parent) */
body[data-theme="dark"] .Select-menu-outer,
body[data-theme="dark"] .Select-menu,
body[data-theme="dark"] .Select-option {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
}
body[data-theme="dark"] .Select-option.is-focused,
body[data-theme="dark"] .Select-option.is-selected,
body[data-theme="dark"] .Select-option:hover {
  background-color: #d4e1ef !important;
  color: #1a2332 !important;
}

/* === Editor card surface stays light === */
body[data-theme="dark"] .editor-card,
body[data-theme="dark"] .report-card,
body[data-theme="dark"] #editor-pane,
body[data-theme="dark"] #editor-content {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
}

/* === Editor input fields === */
body[data-theme="dark"] #editor-pane input[type="text"],
body[data-theme="dark"] #editor-pane input[type="date"],
body[data-theme="dark"] #editor-pane input[type="number"],
body[data-theme="dark"] #editor-pane textarea,
body[data-theme="dark"] #editor-content input[type="text"],
body[data-theme="dark"] #editor-content input[type="date"],
body[data-theme="dark"] #editor-content input[type="number"],
body[data-theme="dark"] #editor-content textarea {
  background-color: #ffffff !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}

/* === Labels in editor === */
body[data-theme="dark"] #editor-pane label,
body[data-theme="dark"] #editor-content label,
body[data-theme="dark"] .editor-card label {
  color: #1a2332 !important;
  font-weight: 500 !important;
}

/* === Dash DataTable (FILE ANNOTATIONS) — confirmed working in v5, keep === */
body[data-theme="dark"] .dash-table-container,
body[data-theme="dark"] .dash-spreadsheet,
body[data-theme="dark"] .dash-cell,
body[data-theme="dark"] .dash-header {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
body[data-theme="dark"] .dash-header,
body[data-theme="dark"] .dash-spreadsheet th {
  background-color: #e3eaf1 !important;
  font-weight: 600 !important;
}
body[data-theme="dark"] table,
body[data-theme="dark"] th,
body[data-theme="dark"] td {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
body[data-theme="dark"] th { background-color: #e3eaf1 !important; }

/* === Plotly chart container === */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plotly,
body[data-theme="dark"] .main-svg {
  background-color: #ffffff !important;
}

/* === Two-column list cards keep readable text === */
body[data-theme="dark"] [id*="report-item"] {
  color: #e8f0f8 !important;
}

/* === Sign button === */
body[data-theme="dark"] #sign-btn,
body[data-theme="dark"] button#sign-btn {
  background-color: #0891B2 !important;
  color: #ffffff !important;
}
CSS_EOF

echo "[+] Appended v6 contrast overrides to CSS"

# ----- JS: clientside Plotly font-color patch -----
# Strip any prior v6 JS block
sed -i '/\/\/ v6 plotly font patch/,$d' "$JS"

cat >> "$JS" <<'JS_EOF'

// v6 plotly font patch — Plotly axis text was invisible because figure has no font.color set.
// MutationObserver patches every Graph after Dash renders it.
(function(){
  function patchPlotly(el) {
    if (!el || el.__nc_patched) return;
    var dark = document.body.getAttribute('data-theme') === 'dark';
    var fontColor = dark ? '#1a2332' : '#1a2332'; // dark text on white panel in both
    try {
      if (window.Plotly && el._fullLayout) {
        window.Plotly.relayout(el, {
          'font.color': fontColor,
          'xaxis.color': fontColor,
          'yaxis.color': fontColor,
          'xaxis.tickfont.color': fontColor,
          'yaxis.tickfont.color': fontColor,
          'xaxis.title.font.color': fontColor,
          'yaxis.title.font.color': fontColor,
          'title.font.color': fontColor,
          'legend.font.color': fontColor,
          'paper_bgcolor': '#ffffff',
          'plot_bgcolor': '#ffffff'
        });
        el.__nc_patched = true;
      }
    } catch(e) { console.log('plotly patch skipped:', e); }
  }
  function patchAll() {
    document.querySelectorAll('.js-plotly-plot').forEach(patchPlotly);
  }
  // Initial + observe new Graphs added by callbacks
  var obs = new MutationObserver(function(){ setTimeout(patchAll, 200); });
  obs.observe(document.body, {childList: true, subtree: true});
  // Also re-patch on theme toggle
  document.addEventListener('click', function(e){
    if (e.target && e.target.id === 'theme-toggle') {
      document.querySelectorAll('.js-plotly-plot').forEach(function(el){ el.__nc_patched = false; });
      setTimeout(patchAll, 100);
    }
  });
  // Periodic safety net (Plotly sometimes redraws)
  setInterval(patchAll, 3000);
})();
JS_EOF

echo "[+] Appended v6 Plotly font patch to JS"

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
echo "    Click a report card → verify chart shows axis labels + bars,"
echo "    Signer dropdown is readable, End Date matches Start Date."
