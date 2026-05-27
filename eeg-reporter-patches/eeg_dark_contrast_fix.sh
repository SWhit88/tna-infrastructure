#!/bin/bash
# Fix dark-mode contrast issues:
#  1. Section headings (h2/h3/h4) brighter — light teal instead of dim navy
#  2. Main title brighter
#  3. Dampen the body bg from #0f1620 -> #1c2433 (less stark next to surfaces)
#  4. Surfaces #1a2332 -> #232d40 (also slightly lighter so contrast feels right)
#  5. Date picker placeholder color fixed
#  6. Inputs get explicit text color so placeholder/value is visible
#
# Pure CSS edit — appends a "dark contrast overrides" block at the end of
# neurochart-theme.css so it wins over earlier rules. No JS, no Python.
set -e
cd ~/eeg-reporter/assets

if [ ! -f neurochart-theme.css ]; then
    echo "FATAL: neurochart-theme.css not found"
    exit 1
fi

# Bail if already injected — keeps script idempotent
if grep -q "Dark mode contrast overrides v1" neurochart-theme.css; then
    echo "[*] Contrast overrides already present — replacing"
    # Strip everything from the marker onward, then re-append
    sed -i '/\/\* ========== Dark mode contrast overrides v1/,$d' neurochart-theme.css
fi

cat >> neurochart-theme.css <<'CSS'

/* ========== Dark mode contrast overrides v1 (2026-05-27) ========== */
body[data-theme="dark"] {
  /* Softer body, less stark surface */
  --nc-bg:          #1c2433;
  --nc-surface:     #232d40;
  --nc-surface-alt: #2c3850;
  --nc-border:      #3a4660;

  /* MUCH brighter accents — these were the unreadable parts */
  --nc-navy:        #7aa8e0;   /* was #4a7ab8 — section headings */
  --nc-navy-light:  #9bc0ee;
  --nc-teal:        #3dd3ed;
  --nc-teal-light:  #6ee0f1;

  /* Text */
  --nc-text:        #eef3fa;
  --nc-text-muted:  #a8b5cc;
}

/* Main title in dark mode — use teal, brighter than navy */
body[data-theme="dark"] h1 {
  color: var(--nc-teal) !important;
  border-bottom-color: var(--nc-teal) !important;
}

/* Section headings (h2/h3/h4) — force readable light navy */
body[data-theme="dark"] h2,
body[data-theme="dark"] h3,
body[data-theme="dark"] h4,
body[data-theme="dark"] h5,
body[data-theme="dark"] h6 {
  color: #9bc0ee !important;
}

/* Inputs in dark mode — fix placeholder visibility */
body[data-theme="dark"] input,
body[data-theme="dark"] textarea,
body[data-theme="dark"] select {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
}
body[data-theme="dark"] input::placeholder,
body[data-theme="dark"] textarea::placeholder {
  color: #6f7d96 !important;
  opacity: 1;
}

/* react-select (dropdowns) text */
body[data-theme="dark"] .Select-control,
body[data-theme="dark"] .Select-placeholder,
body[data-theme="dark"] .Select-value,
body[data-theme="dark"] .Select-value-label {
  color: var(--nc-text) !important;
  background: var(--nc-surface) !important;
}

/* Date range picker — was nearly invisible */
body[data-theme="dark"] .DateInput,
body[data-theme="dark"] .DateInput_input,
body[data-theme="dark"] .DateRangePickerInput {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}
body[data-theme="dark"] .DateInput_input::placeholder {
  color: #6f7d96 !important;
  opacity: 1;
}
body[data-theme="dark"] .DateRangePickerInput_arrow,
body[data-theme="dark"] .DateRangePickerInput_clearDates_svg {
  fill: var(--nc-text-muted) !important;
}

/* Plotly chart background — soften the bright white panel */
body[data-theme="dark"] .js-plotly-plot,
body[data-theme="dark"] .plot-container,
body[data-theme="dark"] .main-svg {
  background: var(--nc-surface) !important;
}
body[data-theme="dark"] .js-plotly-plot .plotly text {
  fill: var(--nc-text) !important;
}

/* Editor pane / main content panels — anything explicitly white */
body[data-theme="dark"] [style*="background:#fff"],
body[data-theme="dark"] [style*="background: #fff"],
body[data-theme="dark"] [style*="background-color:#fff"],
body[data-theme="dark"] [style*="background-color: #fff"],
body[data-theme="dark"] [style*="backgroundColor:#fff"],
body[data-theme="dark"] [style*="background:#ffffff"],
body[data-theme="dark"] [style*="background-color:#ffffff"] {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
}

/* Report cards in dark mode — surface, not bright white */
body[data-theme="dark"] [id*="report-item"] {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
}
body[data-theme="dark"] [id*="report-item"]:hover {
  background: var(--nc-surface-alt) !important;
}
CSS

echo "[+] Appended dark-mode contrast overrides to neurochart-theme.css"
ls -lh ~/eeg-reporter/assets/

echo
echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

echo
echo "[*] Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true

echo
echo "[✓] Done. Hard-reload (Ctrl+Shift+R) and toggle dark mode."
echo "    If you want to revert this overrides block only:"
echo "      sed -i '/\/\* ========== Dark mode contrast overrides v1/,\$d' ~/eeg-reporter/assets/neurochart-theme.css"
