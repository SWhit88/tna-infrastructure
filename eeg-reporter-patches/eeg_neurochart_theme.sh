#!/usr/bin/env bash
# Restyle the EEG Reporter to match NeuroChart's visual identity.
# - Navy: #1e3a5f (primary, headers, draft buttons, borders)
# - Teal: #0891B2 (accent, focus, links, preview button)
# - Signed-green stays #006600 for status-clarity (clinical signal)
# - Error-red stays #cc0000
#
# Files written:
#   ~/eeg-reporter/assets/neurochart-theme.css   (new — auto-loaded by Dash)
#
# No Python source changes. Restart picks up the new asset.

set -euo pipefail
ASSETS=~/eeg-reporter/assets
mkdir -p "$ASSETS"

CSS="$ASSETS/neurochart-theme.css"

cat > "$CSS" <<'CSS'
/* =====================================================================
   NeuroChart Theme for EEG Reporter
   Palette:
     --nc-navy:        #1e3a5f  (primary)
     --nc-navy-light:  #2c5582  (hover/border)
     --nc-navy-dark:   #14283f  (depth)
     --nc-teal:        #0891b2  (accent)
     --nc-teal-light:  #22b8d4  (hover)
     --nc-teal-dark:   #0e7490  (active)
     --nc-bg:          #f7f9fc  (page surface)
     --nc-surface:     #ffffff  (cards)
     --nc-border:      #d6dde6
     --nc-muted:       #6b7a90
     --nc-text:        #1a2332
     --nc-success:     #006600  (signed, unchanged for clinical clarity)
     --nc-warning:     #cc6600  (unlock)
     --nc-danger:      #cc0000
   ===================================================================== */

:root {
  --nc-navy: #1e3a5f;
  --nc-navy-light: #2c5582;
  --nc-navy-dark: #14283f;
  --nc-teal: #0891b2;
  --nc-teal-light: #22b8d4;
  --nc-teal-dark: #0e7490;
  --nc-bg: #f7f9fc;
  --nc-surface: #ffffff;
  --nc-border: #d6dde6;
  --nc-muted: #6b7a90;
  --nc-text: #1a2332;
  --nc-success: #006600;
  --nc-warning: #cc6600;
  --nc-danger: #cc0000;
}

/* ---- Page surface ---- */
html, body, #react-entry-point, ._dash-undo-redo {
  background-color: var(--nc-bg) !important;
  color: var(--nc-text) !important;
  font-family: -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
}

/* ---- Page header (the navy banner with "Tallahassee Neurology Associates") ---- */
h1 {
  color: var(--nc-navy) !important;
  font-weight: 700 !important;
  letter-spacing: -0.01em;
}

h1 + p, h1 + div, h2, h3 {
  color: var(--nc-muted) !important;
}

/* The horizontal rule under the header */
hr {
  border: none !important;
  border-top: 2px solid var(--nc-teal) !important;
  margin: 0 0 16px 0 !important;
}

/* ---- Report list (left column) ---- */
/* Patient name title in each report-item */
[id^="{\"type\":\"report-item\""] {
  background-color: var(--nc-surface) !important;
  border: 1px solid var(--nc-border) !important;
  border-left: 4px solid var(--nc-navy) !important;
  border-radius: 6px !important;
  padding: 10px 12px !important;
  margin-bottom: 6px !important;
  transition: all 0.15s ease-in-out !important;
}

[id^="{\"type\":\"report-item\""]:hover {
  border-left-color: var(--nc-teal) !important;
  background-color: #eef4fb !important;
  cursor: pointer !important;
  transform: translateX(2px);
}

/* "Reports" sidebar heading */
h2, h3, .sidebar-heading {
  color: var(--nc-navy) !important;
}

/* "1897 of 1897 reports" counter */
[id="report-count"] {
  color: var(--nc-muted) !important;
  font-size: 9pt !important;
  letter-spacing: 0.02em;
}

/* ---- Search box + filters ---- */
input[type="text"], input[type="date"], textarea,
.Select-control, .Select-input input {
  background-color: var(--nc-surface) !important;
  border: 1px solid var(--nc-border) !important;
  border-radius: 6px !important;
  padding: 6px 10px !important;
  color: var(--nc-text) !important;
  font-size: 10pt !important;
  transition: border-color 0.15s, box-shadow 0.15s !important;
}

input[type="text"]:focus, input[type="date"]:focus, textarea:focus,
.Select-control.is-focused {
  border-color: var(--nc-teal) !important;
  box-shadow: 0 0 0 3px rgba(8, 145, 178, 0.15) !important;
  outline: none !important;
}

/* Dropdown */
.Select-control {
  height: 34px !important;
}
.Select-menu-outer {
  border: 1px solid var(--nc-border) !important;
  border-radius: 6px !important;
  box-shadow: 0 4px 12px rgba(30, 58, 95, 0.08) !important;
}
.Select-option.is-focused {
  background-color: #eef4fb !important;
  color: var(--nc-navy) !important;
}

/* Date picker */
.DateInput_input {
  padding: 6px 10px !important;
  font-size: 10pt !important;
  color: var(--nc-text) !important;
}
.DateRangePickerInput, .SingleDatePickerInput {
  border: 1px solid var(--nc-border) !important;
  border-radius: 6px !important;
  background-color: var(--nc-surface) !important;
}

/* ---- Buttons (action row + downloads) ---- */
/* Generic button base */
button, .dash-button {
  font-family: inherit !important;
  font-weight: 500 !important;
  letter-spacing: 0.01em !important;
  transition: background-color 0.15s, transform 0.05s, box-shadow 0.15s !important;
  border: none !important;
  border-radius: 6px !important;
  cursor: pointer !important;
  padding: 8px 16px !important;
  font-size: 10pt !important;
}

button:hover, .dash-button:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 6px rgba(30, 58, 95, 0.15) !important;
}

button:active, .dash-button:active {
  transform: translateY(0);
}

/* Save Draft button — navy primary */
#btn-save-draft {
  background-color: var(--nc-navy) !important;
  color: white !important;
}
#btn-save-draft:hover {
  background-color: var(--nc-navy-light) !important;
}

/* Sign & Finalize — success green (kept) */
#btn-sign {
  background-color: var(--nc-success) !important;
  color: white !important;
}
#btn-sign:hover {
  background-color: #008800 !important;
}

/* Save & Preview — teal accent */
#btn-preview {
  background-color: var(--nc-teal) !important;
  color: white !important;
}
#btn-preview:hover {
  background-color: var(--nc-teal-light) !important;
}

/* Unlock — warning orange (kept but rounded) */
#btn-unlock {
  background-color: var(--nc-warning) !important;
  color: white !important;
}
#btn-unlock:hover {
  background-color: #dd7711 !important;
}

/* Download Signed PDF link — green like Sign */
a[href*="/pdf/signed/"] {
  background-color: var(--nc-success) !important;
  color: white !important;
  padding: 8px 16px !important;
  border-radius: 6px !important;
  text-decoration: none !important;
  font-size: 10pt !important;
  font-weight: 500 !important;
  display: inline-block;
  transition: background-color 0.15s !important;
}
a[href*="/pdf/signed/"]:hover {
  background-color: #008800 !important;
  text-decoration: none !important;
}

/* ---- Right pane (report-detail) ---- */
#report-detail {
  background-color: var(--nc-surface) !important;
  border-radius: 8px !important;
  padding: 20px !important;
  box-shadow: 0 1px 3px rgba(30, 58, 95, 0.06) !important;
  border: 1px solid var(--nc-border) !important;
}

/* Patient name (large header inside report-detail) */
#report-detail h1, #report-detail h2 {
  color: var(--nc-navy) !important;
  font-weight: 700 !important;
  margin-top: 0 !important;
}

/* DRAFT / FINAL status pill */
#report-detail > div:first-child + div,
[style*="DRAFT"], [style*="FINAL"] {
  font-weight: 600 !important;
  letter-spacing: 0.02em;
}

/* PDR | Symmetry | Assessment summary strip */
#report-detail > div[style*="background"] {
  background-color: #eef4fb !important;
  border-left: 4px solid var(--nc-teal) !important;
  padding: 10px 14px !important;
  border-radius: 4px !important;
  margin-bottom: 16px !important;
  font-size: 10pt !important;
}

/* Editor field labels */
label {
  color: var(--nc-muted) !important;
  font-weight: 600 !important;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  font-size: 8pt !important;
}

/* Section headers in editor (Clinical History, Findings, Impression, etc) */
#report-detail label[style*="003366"],
#report-detail label[style*="font-weight: bold"] {
  color: var(--nc-navy) !important;
  text-transform: none !important;
  font-size: 11pt !important;
  border-bottom: 1px solid var(--nc-border) !important;
  padding-bottom: 4px !important;
  margin-top: 16px !important;
  display: block !important;
}

/* Editor status (Saved / Signed messages) */
#editor-status {
  margin-top: 14px !important;
  padding: 8px 12px !important;
  border-radius: 6px !important;
  font-size: 10pt !important;
  background-color: transparent !important;
}

/* Help text under buttons */
#report-detail div[style*="italic"] {
  color: var(--nc-muted) !important;
  font-size: 9pt !important;
  margin-top: 8px !important;
}

/* ---- Plotly chart container ---- */
.js-plotly-plot {
  background-color: transparent !important;
}
.plot-container.plotly {
  background-color: transparent !important;
  border-radius: 6px !important;
}

/* ---- Batch status bar at top (if rendered) ---- */
#batch-status-bar:not(:empty) {
  background-color: var(--nc-navy) !important;
  color: white !important;
  padding: 8px 16px !important;
  border-radius: 6px !important;
  margin-bottom: 12px !important;
  font-size: 10pt !important;
}

/* ---- Scrollbar polish ---- */
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-track { background: var(--nc-bg); }
::-webkit-scrollbar-thumb {
  background: var(--nc-border);
  border-radius: 5px;
}
::-webkit-scrollbar-thumb:hover { background: var(--nc-muted); }
CSS

echo "Wrote $CSS ($(wc -l < "$CSS") lines)"

# Restart so Dash picks up the new asset
echo
echo "Restarting reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
cd ~/eeg-reporter
nohup python3 main.py > logs/app.log 2>&1 &
echo "PID: $!"
sleep 3
echo
echo "Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/
echo
echo "Asset visible?"
curl -sS -o /dev/null -w "/assets/neurochart-theme.css -> HTTP %{http_code}\n" \
  http://127.0.0.1:8060/assets/neurochart-theme.css
echo
echo "Tail of app.log:"
tail -n 10 ~/eeg-reporter/logs/app.log
