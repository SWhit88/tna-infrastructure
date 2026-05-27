#!/usr/bin/env bash
# eeg_dark_contrast_fix_v9.sh
# v9 — NUKE all prior dark-mode overrides and rebuild from scratch.
# Light mode is preserved (we only strip "/* Dark mode contrast overrides vN */" blocks).
# Re-adds:
#   - Maximum-specificity rules for End Date (both DateInput halves)
#   - Signer dropdown via pattern-id [id*="interpreting_physician"]
#   - Plotly font/bg patch via JS (was working for chart axis text)
#   - All other dark-mode controls (filter bar, editor, data table)
set -euo pipefail

CSS=~/eeg-reporter/assets/neurochart-theme.css
JS=~/eeg-reporter/assets/theme-toggle.js

[[ -f "$CSS" ]] || { echo "[!] $CSS missing"; exit 1; }
[[ -f "$JS" ]]  || { echo "[!] $JS missing"; exit 1; }

# Timestamped backups
ts=$(date +%Y%m%d-%H%M%S)
cp "$CSS" "$CSS.bak-$ts-pre-v9"
cp "$JS"  "$JS.bak-$ts-pre-v9"
echo "[*] Backups: $CSS.bak-$ts-pre-v9 / $JS.bak-$ts-pre-v9"

# Strip ALL prior "Dark mode contrast overrides vN" blocks from CSS
sed -i '/\/\* Dark mode contrast overrides v[0-9]\+ \*\//,$d' "$CSS"

# Strip prior v6 JS Plotly patch
sed -i '/\/\/ v[0-9]\+ plotly font patch/,$d' "$JS"

# ---------- v9 CSS block (single canonical dark-mode rules) ----------
cat >> "$CSS" <<'CSS_EOF'

/* Dark mode contrast overrides v9 */
/* === RULE: every selector below is scoped to html body[data-theme="dark"] === */
/* === This is the ONLY dark-mode override block. No prior versions. ===     */

/* ---------- FILTER BAR ---------- */
html body[data-theme="dark"] #search-box input {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}
html body[data-theme="dark"] #search-box input::placeholder {
  color: #4a5a6a !important;
}

html body[data-theme="dark"] #filter-status .Select-control,
html body[data-theme="dark"] #filter-referring-md .Select-control,
html body[data-theme="dark"] #filter-ordering-md .Select-control,
html body[data-theme="dark"] #filter-year .Select-control,
html body[data-theme="dark"] #filter-month .Select-control,
html body[data-theme="dark"] #sort-by .Select-control {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}

/* ---------- DATE RANGE PICKER (the End Date holy grail) ---------- */
/* Highest specificity possible. Targets EVERY known dash DateInput class. */
html body[data-theme="dark"] #filter-date-range,
html body[data-theme="dark"] #filter-date-range > div,
html body[data-theme="dark"] #filter-date-range div.DateRangePickerInput,
html body[data-theme="dark"] #filter-date-range div.DateRangePickerInput__withBorder,
html body[data-theme="dark"] #filter-date-range div.DateInput,
html body[data-theme="dark"] #filter-date-range div.DateInput_1,
html body[data-theme="dark"] #filter-date-range div.DateInput_2,
html body[data-theme="dark"] #filter-date-range input,
html body[data-theme="dark"] #filter-date-range input.DateInput_input,
html body[data-theme="dark"] #filter-date-range input.DateInput_input_1,
html body[data-theme="dark"] #filter-date-range input.DateInput_input_2,
html body[data-theme="dark"] #filter-date-range input.DateInput_input__focused {
  background-color: #f0f4f8 !important;
  background: #f0f4f8 !important;
  color: #1a2332 !important;
  -webkit-text-fill-color: #1a2332 !important;
  border-color: #2a4a6f !important;
}
html body[data-theme="dark"] #filter-date-range input::placeholder,
html body[data-theme="dark"] #filter-date-range input::-webkit-input-placeholder,
html body[data-theme="dark"] #filter-date-range input::-moz-placeholder {
  color: #4a5a6a !important;
  -webkit-text-fill-color: #4a5a6a !important;
  opacity: 1 !important;
}
html body[data-theme="dark"] #filter-date-range svg,
html body[data-theme="dark"] #filter-date-range .DateRangePickerInput_arrow,
html body[data-theme="dark"] #filter-date-range .DateRangePickerInput_arrow svg {
  color: #1a2332 !important;
  fill: #1a2332 !important;
}

/* ---------- DROPDOWN MENUS (global - covers signer + all other dropdowns) ---------- */
/* Note: signer uses pattern-id, others use direct ids. We catch all via .Select-* */
html body[data-theme="dark"] .Select-control {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
  border-color: #2a4a6f !important;
}
html body[data-theme="dark"] .Select-control .Select-value-label,
html body[data-theme="dark"] .Select-control .Select-value,
html body[data-theme="dark"] .Select-control .Select-placeholder,
html body[data-theme="dark"] .Select-control .Select-input > input,
html body[data-theme="dark"] .Select-multi-value-wrapper {
  color: #1a2332 !important;
}
html body[data-theme="dark"] .Select-menu-outer,
html body[data-theme="dark"] .Select-menu,
html body[data-theme="dark"] .Select-option {
  background-color: #f0f4f8 !important;
  color: #1a2332 !important;
}
html body[data-theme="dark"] .Select-option.is-focused,
html body[data-theme="dark"] .Select-option.is-selected,
html body[data-theme="dark"] .Select-option:hover {
  background-color: #d4e1ef !important;
  color: #1a2332 !important;
}

/* ---------- EDITOR PANE ---------- */
html body[data-theme="dark"] #editor-pane,
html body[data-theme="dark"] #editor-content,
html body[data-theme="dark"] .editor-card {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
}
html body[data-theme="dark"] #editor-pane input,
html body[data-theme="dark"] #editor-pane textarea,
html body[data-theme="dark"] #editor-content input,
html body[data-theme="dark"] #editor-content textarea {
  background-color: #ffffff !important;
  color: #1a2332 !important;
  border: 1px solid #2a4a6f !important;
}
html body[data-theme="dark"] #editor-pane label,
html body[data-theme="dark"] #editor-content label {
  color: #1a2332 !important;
  font-weight: 500 !important;
}

/* ---------- DATA TABLE (FILE ANNOTATIONS) ---------- */
html body[data-theme="dark"] .dash-table-container,
html body[data-theme="dark"] .dash-spreadsheet,
html body[data-theme="dark"] .dash-cell,
html body[data-theme="dark"] .dash-header {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
html body[data-theme="dark"] .dash-header,
html body[data-theme="dark"] .dash-spreadsheet th {
  background-color: #e3eaf1 !important;
  font-weight: 600 !important;
}
html body[data-theme="dark"] table,
html body[data-theme="dark"] th,
html body[data-theme="dark"] td {
  background-color: #f7f9fb !important;
  color: #1a2332 !important;
  border-color: #c0cdd9 !important;
}
html body[data-theme="dark"] th {
  background-color: #e3eaf1 !important;
}

/* ---------- PLOTLY CHART CONTAINER ---------- */
html body[data-theme="dark"] .js-plotly-plot,
html body[data-theme="dark"] .plotly,
html body[data-theme="dark"] .main-svg {
  background-color: #ffffff !important;
}

/* ---------- FALLBACK "Spectral data unavailable" PARAGRAPH ---------- */
/* When fig.data is empty, app.py renders <p style="color:#999">. Override here. */
html body[data-theme="dark"] p[style*="color"][style*="999"] {
  color: #b3d0f0 !important;
  background-color: rgba(30, 58, 95, 0.4) !important;
  padding: 12px !important;
  border-radius: 6px !important;
  text-align: center !important;
  font-style: italic !important;
}

/* ---------- TWO-COLUMN LIST CARDS ---------- */
html body[data-theme="dark"] [id*="report-item"] {
  color: #e8f0f8 !important;
}

/* ---------- SIGN BUTTON ---------- */
html body[data-theme="dark"] #sign-btn,
html body[data-theme="dark"] button#sign-btn {
  background-color: #0891B2 !important;
  color: #ffffff !important;
}
CSS_EOF

echo "[+] v9 CSS block appended (all prior dark blocks stripped first)"

# ---------- v9 JS: re-add Plotly font patch ----------
cat >> "$JS" <<'JS_EOF'

// v9 plotly font patch
// Plotly figure has paper_bgcolor=white but no font.color set.
// In dark mode, axis labels/numbers are default dark gray on white panel.
// MutationObserver patches every Graph after Dash renders it.
(function(){
  function patchPlotly(el) {
    if (!el || el.__nc_patched_v9) return;
    try {
      if (window.Plotly && el._fullLayout) {
        window.Plotly.relayout(el, {
          'font.color': '#1a2332',
          'xaxis.color': '#1a2332',
          'yaxis.color': '#1a2332',
          'xaxis.tickfont.color': '#1a2332',
          'yaxis.tickfont.color': '#1a2332',
          'xaxis.title.font.color': '#1a2332',
          'yaxis.title.font.color': '#1a2332',
          'title.font.color': '#1a2332',
          'legend.font.color': '#1a2332'
        });
        el.__nc_patched_v9 = true;
      }
    } catch(e) {}
  }
  function patchAll() {
    document.querySelectorAll('.js-plotly-plot').forEach(patchPlotly);
  }
  var obs = new MutationObserver(function(){ setTimeout(patchAll, 300); });
  obs.observe(document.body, {childList: true, subtree: true});
  document.addEventListener('click', function(e){
    if (e.target && e.target.id === 'theme-toggle') {
      document.querySelectorAll('.js-plotly-plot').forEach(function(el){ el.__nc_patched_v9 = false; });
      setTimeout(patchAll, 200);
    }
  });
  setTimeout(patchAll, 1000);
})();
JS_EOF

echo "[+] v9 Plotly JS patch appended"

# Bump version to confirm cache flush
sed -i "s/EEG_REPORTER_VERSION = '[^']*'/EEG_REPORTER_VERSION = 'v1.0.9'/" "$JS"
echo "[+] Version bumped to v1.0.9"

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
echo "[*] Verifying v9 markers in served files..."
curl -s http://127.0.0.1:8060/assets/neurochart-theme.css | grep -c "Dark mode contrast overrides v9" | xargs echo "  CSS v9 markers served:"
curl -s http://127.0.0.1:8060/assets/theme-toggle.js | grep -c "v9 plotly font patch" | xargs echo "  JS  v9 markers served:"

echo
echo "[*] CSS file size:"
ls -la "$CSS"

echo
echo "[✓] Hard-reload (Ctrl+Shift+R) — should see v1.0.9 in footer."
echo "    Light mode unchanged. Dark mode rebuilt clean."
