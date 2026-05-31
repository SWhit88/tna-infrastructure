#!/usr/bin/env bash
# eeg_dark_chart_v4.sh
# v4: Beat Plotly's inline `style="background: white"` on .main-svg via JS.
# Discovery via DevTools inspector on 2026-05-31:
#   - .main-svg has INLINE style="background: white" written by Plotly
#   - CSS !important loses to inline shorthand `background:` for some browsers/orderings
#   - Chart bars/text exist but plot area renders solid white in dark mode
# Strategy:
#   1) JS observer that finds every .main-svg, .svg-container, .js-plotly-plot,
#      and sets style.backgroundColor = '' / 'transparent' when dark theme active.
#   2) Re-runs on Dash component updates (MutationObserver on the report-detail div).
#   3) CSS keeps the gridline/text fill rules from v3 (they DID work — chart text was
#      the right color, the white plot bg just hid it).

set -euo pipefail
cd ~/eeg-reporter

JS=assets/theme-toggle.js
CSS=assets/neurochart-theme.css
ts=$(date +%Y%m%d_%H%M%S)
cp "$JS"  "${JS}.bak.${ts}"
cp "$CSS" "${CSS}.bak.${ts}"

# 1) Strip any prior PLOTLY_BG_FORCE block (idempotent)
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/theme-toggle.js')
s = p.read_text()
pat = re.compile(r'/\*\s*BEGIN PLOTLY_BG_FORCE.*?END PLOTLY_BG_FORCE\s*\*/\s*', re.DOTALL)
s = pat.sub('', s)
p.write_text(s)
PY

# 2) Append the JS that overrides Plotly's inline white bg in dark mode
cat >> "$JS" <<'JS_EOF'

/* BEGIN PLOTLY_BG_FORCE_v4 - 2026-05-31
   Plotly writes style="background: white" inline on .main-svg elements.
   Inline styles beat CSS !important in some specificity orderings, so we
   forcibly clear/override them via JS whenever the dark theme is active. */
(function(){
  function isDark(){
    return document.body && document.body.getAttribute('data-theme') === 'dark';
  }
  function fixPlotlyBg(){
    if(!isDark()) return;
    var surface = '#2a3548'; // matches --nc-surface
    document.querySelectorAll('.js-plotly-plot, .plot-container, .svg-container, .main-svg')
      .forEach(function(el){
        // Force backgroundColor (beats Plotly's inline `background: white` shorthand
        // because individual property wins over shorthand reset when set later)
        el.style.setProperty('background-color', surface, 'important');
        el.style.setProperty('background', surface, 'important');
      });
    // Also fix the SVG <rect class="bg"> elements that Plotly draws as the plot area
    document.querySelectorAll('.main-svg rect.bg, .main-svg .bg').forEach(function(r){
      r.setAttribute('fill', surface);
      r.style.setProperty('fill', surface, 'important');
    });
  }
  // Run on load
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', fixPlotlyBg);
  } else {
    fixPlotlyBg();
  }
  // Re-run when theme toggles (data-theme attribute change on body)
  var bodyObs = new MutationObserver(function(){ fixPlotlyBg(); });
  if(document.body){
    bodyObs.observe(document.body, { attributes: true, attributeFilter: ['data-theme'] });
  }
  // Re-run when Dash re-renders the report (new charts appear)
  var contentObs = new MutationObserver(function(muts){
    var needsFix = false;
    for(var i=0;i<muts.length;i++){
      if(muts[i].addedNodes && muts[i].addedNodes.length){ needsFix = true; break; }
    }
    if(needsFix) setTimeout(fixPlotlyBg, 50);
  });
  // Observe the main app container (react-entry-point) for any subtree changes
  var watchAttach = function(){
    var root = document.getElementById('react-entry-point') || document.body;
    if(root){
      contentObs.observe(root, { childList: true, subtree: true });
    }
  };
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', watchAttach);
  } else {
    watchAttach();
  }
  // Periodic safety net every 2s in case Plotly redraws without triggering mutations
  setInterval(fixPlotlyBg, 2000);
  // Expose for console testing: window.__fixPlotlyBg()
  window.__fixPlotlyBg = fixPlotlyBg;
})();
/* END PLOTLY_BG_FORCE_v4 */
JS_EOF

# 3) Bump version to v1.0.16 so we know the new bundle loaded
python3 <<'PY'
import re, pathlib
for fn in ('assets/theme-toggle.js', 'app.py'):
    p = pathlib.Path(fn)
    if not p.exists(): continue
    s = p.read_text()
    s2 = re.sub(r"v1\.0\.1[0-9]", "v1.0.16", s)
    if s != s2:
        p.write_text(s2)
        print(f"{fn} bumped to v1.0.16")
PY

echo "----- restarting eeg-reporter -----"
pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
echo "----- last 15 log lines -----"
tail -n 15 /tmp/eeg-reporter.log || true
echo
echo "v4 applied. Hard refresh: Ctrl+Shift+R"
echo "Footer must read: EEG Reporter v1.0.16"
echo "After refresh, in console try: __fixPlotlyBg()   (should re-apply on demand)"
