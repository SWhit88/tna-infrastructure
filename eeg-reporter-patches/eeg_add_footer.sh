#!/bin/bash
# Adds a small footer with copyright + version to the EEG Reporter dashboard.
# Pure asset-layer addition — appends to existing theme-toggle.js so the
# floating footer renders client-side. No Python changes.
#
# Version starts at v1.0.0. To bump: edit the EEG_REPORTER_VERSION constant
# in theme-toggle.js (one line change), no rebuild needed.
set -e
cd ~/eeg-reporter/assets

if [ ! -f theme-toggle.js ]; then
    echo "FATAL: theme-toggle.js not found — run eeg_neurochart_theme_combined.sh first"
    exit 1
fi

# Bail if footer already injected
if grep -q "nc-app-footer" theme-toggle.js; then
    echo "[*] Footer already present in theme-toggle.js — updating version only"
    # Replace existing version line
    sed -i "s/var EEG_REPORTER_VERSION = '[^']*'/var EEG_REPORTER_VERSION = 'v1.0.0'/" theme-toggle.js
else
    echo "[*] Appending footer block to theme-toggle.js"
    cat >> theme-toggle.js <<'JS'

/* ---------- App footer (copyright + version) ---------- */
(function () {
  var EEG_REPORTER_VERSION = 'v1.0.0';
  var COPYRIGHT_HOLDER = 'Tallahassee Neurology Associates';

  function addFooter() {
    if (document.getElementById('nc-app-footer')) return;
    var year = new Date().getFullYear();
    var footer = document.createElement('div');
    footer.id = 'nc-app-footer';
    footer.innerHTML =
      '<span class="nc-footer-copyright">© ' + year + ' ' + COPYRIGHT_HOLDER + '</span>' +
      '<span class="nc-footer-sep"> · </span>' +
      '<span class="nc-footer-version">EEG Reporter ' + EEG_REPORTER_VERSION + '</span>';
    document.body.appendChild(footer);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addFooter);
  } else {
    addFooter();
  }
  setTimeout(addFooter, 500);
  setTimeout(addFooter, 1500);
})();
JS
fi

# Add CSS for the footer if not already present
if ! grep -q "nc-app-footer" neurochart-theme.css; then
    echo "[*] Appending footer CSS to neurochart-theme.css"
    cat >> neurochart-theme.css <<'CSS'

/* ---------- App footer ---------- */
#nc-app-footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 9998;
  padding: 6px 16px;
  font-size: 8.5pt;
  color: var(--nc-text-muted);
  background: var(--nc-surface);
  border-top: 1px solid var(--nc-border);
  text-align: center;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  letter-spacing: 0.02em;
}
#nc-app-footer .nc-footer-version {
  color: var(--nc-teal);
  font-weight: 600;
}
#nc-app-footer .nc-footer-sep {
  opacity: 0.5;
}
/* Add body bottom-padding so footer doesn't overlap content */
body {
  padding-bottom: 32px !important;
}
CSS
else
    echo "[*] Footer CSS already present — skipping"
fi

echo
echo "[*] Verifying files:"
ls -lh ~/eeg-reporter/assets/
echo
echo "[*] Footer version line:"
grep "EEG_REPORTER_VERSION = " theme-toggle.js
echo
echo "[*] Restarting eeg-reporter (assets are auto-served, but rescan to be safe)..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

echo
echo "[*] Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
curl -sS -o /dev/null -w "JS  HTTP %{http_code}\n" http://127.0.0.1:8060/assets/theme-toggle.js || true
curl -sS -o /dev/null -w "CSS HTTP %{http_code}\n" http://127.0.0.1:8060/assets/neurochart-theme.css || true

echo
echo "[✓] Done. Hard-reload the dashboard (Ctrl+Shift+R)."
echo "    Footer should show:  © 2026 Tallahassee Neurology Associates · EEG Reporter v1.0.0"
echo
echo "To bump version later, edit one line:"
echo "    sed -i \"s/EEG_REPORTER_VERSION = '[^']*'/EEG_REPORTER_VERSION = 'v1.0.1'/\" ~/eeg-reporter/assets/theme-toggle.js"
