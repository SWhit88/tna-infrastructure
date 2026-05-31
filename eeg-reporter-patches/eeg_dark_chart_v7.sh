#!/usr/bin/env bash
# eeg_dark_chart_v7.sh
# v7 fixes light mode regression from v6.
# Discovery: v6 paints inline `!important` styles in dark mode, but clean-up via
# style.removeProperty('fill') doesn't actually un-paint the marked elements in
# practice — possibly because Plotly re-renders + we keep re-marking, or because
# the SVG fill attribute (not just style) persists.
# Strategy: instead of trying to STRIP overrides, explicitly RESET to Plotly's
# default light-mode values when in light mode. Two known states, two paint
# functions, no fragile cleanup.

set -euo pipefail
cd ~/eeg-reporter

JS=assets/theme-toggle.js
ts=$(date +%Y%m%d_%H%M%S)
cp "$JS" "${JS}.bak.${ts}"

# Strip prior PLOTLY_BG_FORCE blocks
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/theme-toggle.js')
s = p.read_text()
pat = re.compile(r'/\*\s*BEGIN PLOTLY_BG_FORCE.*?END PLOTLY_BG_FORCE\S*\s*\*/\s*', re.DOTALL)
s = pat.sub('', s)
p.write_text(s)
PY

cat >> "$JS" <<'JS_EOF'

/* BEGIN PLOTLY_BG_FORCE_v7 - 2026-05-31
   Explicit two-state paint: dark mode AND light mode both actively paint.
   No cleanup logic - just always-correct values for whichever theme is active. */
(function(){
  // Dark palette
  var DARK_SURFACE = '#2a3548';
  var DARK_TEXT    = '#f0f5fb';
  var DARK_MUTED   = '#b8c3d6';
  var DARK_BORDER  = '#45526c';
  // Light palette (Plotly-ish defaults)
  var LIGHT_SURFACE = '#ffffff';
  var LIGHT_TEXT    = '#444444';
  var LIGHT_MUTED   = '#444444';
  var LIGHT_BORDER  = '#eeeeee';

  function isDark(){
    return document.body && document.body.getAttribute('data-theme') === 'dark';
  }

  function paint(p){
    // Outer containers
    document.querySelectorAll('.js-plotly-plot, .plot-container, .svg-container, svg.main-svg')
      .forEach(function(el){
        el.style.setProperty('background', p.surface, 'important');
        el.style.setProperty('background-color', p.surface, 'important');
      });
    // Plot bg rect
    document.querySelectorAll('svg.main-svg rect.bg, svg.main-svg .bglayer rect').forEach(function(r){
      r.setAttribute('fill', p.surface);
      r.style.setProperty('fill', p.surface, 'important');
    });
    // Text
    document.querySelectorAll('svg.main-svg text').forEach(function(t){
      t.style.setProperty('fill', p.text, 'important');
    });
    // Axis lines, ticks
    document.querySelectorAll('svg.main-svg .xaxis path.domain, svg.main-svg .yaxis path.domain, svg.main-svg .crisp, svg.main-svg .xtick > path, svg.main-svg .ytick > path').forEach(function(l){
      l.style.setProperty('stroke', p.muted, 'important');
    });
    // Gridlines
    document.querySelectorAll('svg.main-svg .gridlayer path, svg.main-svg .xgrid, svg.main-svg .ygrid').forEach(function(g){
      g.style.setProperty('stroke', p.border, 'important');
    });
  }

  function applyTheme(){
    if(isDark()){
      paint({ surface: DARK_SURFACE, text: DARK_TEXT, muted: DARK_MUTED, border: DARK_BORDER });
    } else {
      paint({ surface: LIGHT_SURFACE, text: LIGHT_TEXT, muted: LIGHT_MUTED, border: LIGHT_BORDER });
    }
  }

  function run(){ applyTheme(); }
  if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded', run); } else { run(); }

  var bodyObs = new MutationObserver(applyTheme);
  function attachBody(){
    if(document.body) bodyObs.observe(document.body, { attributes: true, attributeFilter: ['data-theme'] });
  }
  if(document.body) attachBody(); else document.addEventListener('DOMContentLoaded', attachBody);

  var contentObs = new MutationObserver(function(muts){
    for(var i=0;i<muts.length;i++){
      if(muts[i].addedNodes && muts[i].addedNodes.length){
        setTimeout(applyTheme, 30);
        return;
      }
    }
  });
  function attachContent(){
    var root = document.getElementById('react-entry-point') || document.body;
    if(root) contentObs.observe(root, { childList: true, subtree: true });
  }
  if(document.body) attachContent(); else document.addEventListener('DOMContentLoaded', attachContent);

  setInterval(applyTheme, 1500);
  window.__fixPlotlyBg = applyTheme;
  window.__chartDiag = function(){
    var bars = document.querySelectorAll('svg.main-svg .barlayer .point, svg.main-svg g.trace .point, svg.main-svg g.trace rect');
    var texts = document.querySelectorAll('svg.main-svg text');
    console.log('theme:', document.body.getAttribute('data-theme'));
    console.log('bars found:', bars.length);
    bars.forEach(function(b,i){
      var r = b.getBoundingClientRect();
      console.log('  bar',i,'fill:',b.getAttribute('fill'),'rect:',Math.round(r.left)+','+Math.round(r.top)+' '+Math.round(r.width)+'x'+Math.round(r.height));
    });
    console.log('texts:');
    texts.forEach(function(t,i){
      if(i<6) console.log('  text',i,'"'+t.textContent+'" computed fill:',getComputedStyle(t).fill);
    });
  };
})();
/* END PLOTLY_BG_FORCE_v7 */
JS_EOF

# Version bump v1.0.19
python3 <<'PY'
import re, pathlib
for fn in ('assets/theme-toggle.js','app.py'):
    p = pathlib.Path(fn)
    if not p.exists(): continue
    s = p.read_text(); s2 = re.sub(r"v1\.0\.1[0-9]", "v1.0.19", s)
    if s != s2:
        p.write_text(s2); print(fn,'->','v1.0.19')
PY

pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
tail -n 8 /tmp/eeg-reporter.log
echo
echo "v7 applied. Ctrl+Shift+R. Footer = v1.0.19"
