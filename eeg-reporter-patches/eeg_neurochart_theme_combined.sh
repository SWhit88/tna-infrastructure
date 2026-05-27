#!/bin/bash
# Combined: NeuroChart palette (navy/teal) + dark-mode toggle.
# Pure asset-layer change. Writes two files into ~/eeg-reporter/assets/:
#   neurochart-theme.css     — palette + light/dark variable swap
#   theme-toggle.js          — adds a 🌙/☀ button to header, persists choice
# Dash auto-loads anything in assets/. No app.py changes. No restart needed
# (Flask static reload), but we restart anyway to be safe.
set -e
mkdir -p ~/eeg-reporter/assets
cd ~/eeg-reporter/assets

# ----------------------------------------------------------------------
# 1. CSS file
# ----------------------------------------------------------------------
cat > neurochart-theme.css <<'CSS'
/* ============================================================
   NeuroChart Theme for EEG Reporter
   Light mode = default; dark mode = body[data-theme="dark"]
   ============================================================ */

:root {
  --nc-navy:        #1e3a5f;
  --nc-navy-light:  #2c5582;
  --nc-teal:        #0891b2;
  --nc-teal-light:  #22b8d4;
  --nc-bg:          #f7f9fc;
  --nc-surface:     #ffffff;
  --nc-surface-alt: #eef2f7;
  --nc-border:      #d6dde6;
  --nc-text:        #1a2332;
  --nc-text-muted:  #6b7a90;
  --nc-success:     #006600;
  --nc-success-bg:  #e6f4e6;
  --nc-warning:     #cc6600;
  --nc-warning-bg:  #fff4e6;
  --nc-danger:      #cc0000;
  --nc-shadow:      0 1px 3px rgba(30, 58, 95, 0.08);
  --nc-shadow-lg:   0 4px 12px rgba(30, 58, 95, 0.12);
}

body[data-theme="dark"] {
  --nc-navy:        #4a7ab8;
  --nc-navy-light:  #6394d0;
  --nc-teal:        #22b8d4;
  --nc-teal-light:  #4dd0e5;
  --nc-bg:          #0f1620;
  --nc-surface:     #1a2332;
  --nc-surface-alt: #243042;
  --nc-border:      #2c3a52;
  --nc-text:        #e6ecf3;
  --nc-text-muted:  #8a9bb3;
  --nc-success:     #4ade80;
  --nc-success-bg:  #1a3a1f;
  --nc-warning:     #fbbf24;
  --nc-warning-bg:  #3a2a0f;
  --nc-danger:      #f87171;
  --nc-shadow:      0 1px 3px rgba(0, 0, 0, 0.4);
  --nc-shadow-lg:   0 4px 12px rgba(0, 0, 0, 0.5);
}

/* Base */
body {
  background: var(--nc-bg) !important;
  color: var(--nc-text) !important;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
  transition: background 0.2s ease, color 0.2s ease;
}

/* Headings */
h1, h2, h3, h4, h5, h6 {
  color: var(--nc-navy) !important;
  transition: color 0.2s ease;
}

/* Top-level page header (Dash usually renders a div containing the title) */
h1 {
  border-bottom: 2px solid var(--nc-teal) !important;
  padding-bottom: 8px !important;
}

/* Generic text */
p, span, div, label {
  color: inherit;
}

/* ---------- Inputs ---------- */
input[type="text"], input[type="number"], input[type="date"],
input[type="search"], textarea, select,
.dash-dropdown .Select-control, .Select-control {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border: 1px solid var(--nc-border) !important;
  border-radius: 4px !important;
  padding: 6px 10px !important;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
input:focus, textarea:focus, select:focus,
.Select-control.is-focused {
  border-color: var(--nc-teal) !important;
  box-shadow: 0 0 0 3px rgba(8, 145, 178, 0.15) !important;
  outline: none !important;
}

/* Dropdown menu (react-select) */
.Select-menu-outer, .Select-menu {
  background: var(--nc-surface) !important;
  border: 1px solid var(--nc-border) !important;
  color: var(--nc-text) !important;
}
.Select-option {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
}
.Select-option.is-focused, .Select-option:hover {
  background: var(--nc-surface-alt) !important;
}
.Select-value-label, .Select-placeholder {
  color: var(--nc-text) !important;
}

/* ---------- Buttons ---------- */
button {
  border-radius: 4px !important;
  border: none !important;
  padding: 8px 14px !important;
  cursor: pointer;
  font-weight: 600 !important;
  font-size: 9.5pt !important;
  transition: transform 0.12s ease, box-shadow 0.12s ease, background 0.12s ease;
}
button:hover {
  transform: translateY(-1px);
  box-shadow: var(--nc-shadow-lg);
}
button:active {
  transform: translateY(0);
}

/* Specific buttons (color hints by inline style still take precedence,
   but we tighten typography + add hover) */

/* ---------- Cards (report-list items) ---------- */
/* The cards already get inline styles from app.py — we add hover polish */
[id*="report-item"] {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border-color: var(--nc-border) !important;
  transition: transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease;
}
[id*="report-item"]:hover {
  transform: translateX(2px);
  box-shadow: var(--nc-shadow-lg);
  border-color: var(--nc-teal) !important;
}

/* ---------- Right pane / editor surface ---------- */
/* Catch-all for big content panels */
.dash-tab-content, .tab-content {
  background: var(--nc-bg) !important;
}

/* ---------- Theme toggle button ---------- */
#nc-theme-toggle {
  position: fixed !important;
  top: 12px !important;
  right: 16px !important;
  z-index: 9999 !important;
  width: 38px !important;
  height: 38px !important;
  padding: 0 !important;
  border-radius: 50% !important;
  background: var(--nc-surface) !important;
  color: var(--nc-navy) !important;
  border: 1px solid var(--nc-border) !important;
  font-size: 16px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  box-shadow: var(--nc-shadow) !important;
}
#nc-theme-toggle:hover {
  background: var(--nc-surface-alt) !important;
  border-color: var(--nc-teal) !important;
}

/* ---------- Misc Dash widgets ---------- */
.DateInput_input {
  background: var(--nc-surface) !important;
  color: var(--nc-text) !important;
  border: 1px solid var(--nc-border) !important;
}
.DateRangePickerInput {
  background: var(--nc-surface) !important;
  border: 1px solid var(--nc-border) !important;
}

/* Scrollbars in dark mode (WebKit only) */
body[data-theme="dark"] ::-webkit-scrollbar { width: 10px; height: 10px; }
body[data-theme="dark"] ::-webkit-scrollbar-track { background: var(--nc-bg); }
body[data-theme="dark"] ::-webkit-scrollbar-thumb {
  background: var(--nc-border); border-radius: 5px;
}
body[data-theme="dark"] ::-webkit-scrollbar-thumb:hover { background: var(--nc-navy); }

/* Link color */
a { color: var(--nc-teal) !important; }
a:hover { color: var(--nc-teal-light) !important; }

/* Code / pre */
code, pre {
  background: var(--nc-surface-alt) !important;
  color: var(--nc-text) !important;
  border: 1px solid var(--nc-border) !important;
  border-radius: 3px;
  padding: 1px 4px;
}
CSS

# ----------------------------------------------------------------------
# 2. JS file — adds the toggle button and persists the choice
# ----------------------------------------------------------------------
cat > theme-toggle.js <<'JS'
/* NeuroChart theme toggle — adds a floating 🌙/☀ button. */
(function () {
  function apply(theme) {
    document.body.setAttribute('data-theme', theme);
    try { localStorage.setItem('nc-theme', theme); } catch (e) {}
    var btn = document.getElementById('nc-theme-toggle');
    if (btn) btn.textContent = (theme === 'dark') ? '☀' : '🌙';
  }

  function init() {
    if (document.getElementById('nc-theme-toggle')) return;
    var stored = 'light';
    try { stored = localStorage.getItem('nc-theme') || 'light'; } catch (e) {}
    apply(stored);

    var btn = document.createElement('button');
    btn.id = 'nc-theme-toggle';
    btn.type = 'button';
    btn.title = 'Toggle light/dark mode';
    btn.textContent = (stored === 'dark') ? '☀' : '🌙';
    btn.addEventListener('click', function () {
      var cur = document.body.getAttribute('data-theme') || 'light';
      apply(cur === 'dark' ? 'light' : 'dark');
    });
    document.body.appendChild(btn);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  // Re-check after a beat (Dash mounts after initial DOMContentLoaded)
  setTimeout(init, 500);
  setTimeout(init, 1500);
})();
JS

echo "[+] Wrote ~/eeg-reporter/assets/neurochart-theme.css"
echo "[+] Wrote ~/eeg-reporter/assets/theme-toggle.js"
ls -lh ~/eeg-reporter/assets/

# ----------------------------------------------------------------------
# 3. Restart (assets are auto-served but a fresh start ensures Dash rescans)
# ----------------------------------------------------------------------
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
echo "[*] Asset served check:"
curl -sS -o /dev/null -w "CSS HTTP %{http_code}\n" http://127.0.0.1:8060/assets/neurochart-theme.css || true
curl -sS -o /dev/null -w "JS  HTTP %{http_code}\n" http://127.0.0.1:8060/assets/theme-toggle.js || true

echo
echo "[*] Tail of app.log:"
tail -n 10 ~/eeg-reporter/logs/app.log

echo
echo "[✓] Done. Hard-reload the dashboard (Ctrl+Shift+R)."
echo "    Look for 🌙 button top-right. Click to toggle dark mode."
echo
echo "Revert:  rm ~/eeg-reporter/assets/neurochart-theme.css ~/eeg-reporter/assets/theme-toggle.js"
