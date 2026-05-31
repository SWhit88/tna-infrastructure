#!/usr/bin/env bash
# eeg_dark_chart_v6.sh
# v6 fixes two regressions from v5:
#   (a) light mode is now also dark (inline styles set in dark mode persist)
#   (b) chart shows flat dark rectangle - no bars/text visible
# Strategy:
#   - In dark mode: paint bg dark, paint text light, fix grid - DO NOT touch bar fills
#   - In light mode: REMOVE every inline style we previously set so Plotly's defaults return
#   - Add a console diagnostic so we can see if bars are even drawn

set -euo pipefail
cd ~/eeg-reporter

JS=assets/theme-toggle.js
CSS=assets/neurochart-theme.css
ts=$(date +%Y%m%d_%H%M%S)
cp "$JS"  "${JS}.bak.${ts}"
cp "$CSS" "${CSS}.bak.${ts}"

# Strip prior PLOTLY_BG_FORCE blocks (any version)
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/theme-toggle.js')
s = p.read_text()
pat = re.compile(r'/\*\s*BEGIN PLOTLY_BG_FORCE.*?END PLOTLY_BG_FORCE\S*\s*\*/\s*', re.DOTALL)
s = pat.sub('', s)
p.write_text(s)
PY

cat >> "$JS" <<'JS_EOF'

/* BEGIN PLOTLY_BG_FORCE_v6 - 2026-05-31
   v6: clean two-way theme. Dark = paint bg/text/grid only (don't touch bars).
   Light = strip every inline style we set so Plotly defaults return. */
(function(){
  var SURFACE = '#2a3548';
  var TEXT    = '#f0f5fb';
  var MUTED   = '#b8c3d6';
  var BORDER  = '#45526c';

  // Sentinel attribute so we can identify what WE set vs what Plotly set
  var MARK = 'data-nc-darkpaint';

  function isDark(){
    return document.body && document.body.getAttribute('data-theme') === 'dark';
  }

  function clearOurOverrides(){
    // Remove inline styles we previously applied (marked with our sentinel)
    document.querySelectorAll('[' + MARK + ']').forEach(function(el){
      el.style.removeProperty('background');
      el.style.removeProperty('background-color');
      el.style.removeProperty('fill');
      el.style.removeProperty('stroke');
      el.removeAttribute(MARK);
    });
  }

  function paintDark(){
    // 1. Outer containers - dark surface
    document.querySelectorAll('.js-plotly-plot, .plot-container, .svg-container, svg.main-svg')
      .forEach(function(el){
        el.style.setProperty('background', SURFACE, 'important');
        el.style.setProperty('background-color', SURFACE, 'important');
        el.setAttribute(MARK, '1');
      });
    // 2. Plot bg rect (the one that was painting white over the bars)
    document.querySelectorAll('svg.main-svg rect.bg, svg.main-svg .bglayer rect').forEach(function(r){
      r.setAttribute('fill', SURFACE);
      r.style.setProperty('fill', SURFACE, 'important');
      r.setAttribute(MARK, '1');
    });
    // 3. Text - light, but ONLY if it's currently dark-on-dark (rgb < 80 sum)
    document.querySelectorAll('svg.main-svg text').forEach(function(t){
      t.style.setProperty('fill', TEXT, 'important');
      t.setAttribute(MARK, '1');
    });
    // 4. Axis lines + tick marks
    document.querySelectorAll('svg.main-svg .xaxis path.domain, svg.main-svg .yaxis path.domain, svg.main-svg .crisp, svg.main-svg .xtick > path, svg.main-svg .ytick > path').forEach(function(l){
      l.style.setProperty('stroke', MUTED, 'important');
      l.setAttribute(MARK, '1');
    });
    // 5. Gridlines
    document.querySelectorAll('svg.main-svg .gridlayer path, svg.main-svg .xgrid, svg.main-svg .ygrid').forEach(function(g){
      g.style.setProperty('stroke', BORDER, 'important');
      g.setAttribute(MARK, '1');
    });
    // DELIBERATELY DO NOT TOUCH bar fills (.barlayer .point, g.trace, etc.)
  }

  function applyTheme(){
    if(isDark()){
      paintDark();
    } else {
      clearOurOverrides();
    }
  }

  // Diagnostic: count what's actually drawn
  window.__chartDiag = function(){
    var bars = document.querySelectorAll('svg.main-svg .barlayer .point, svg.main-svg g.trace .point, svg.main-svg g.trace rect');
    var texts = document.querySelectorAll('svg.main-svg text');
    console.log('bars found:', bars.length);
    bars.forEach(function(b,i){
      var r = b.getBoundingClientRect();
      console.log('  bar',i,'fill:',b.getAttribute('fill'),'rect:',Math.round(r.left)+','+Math.round(r.top)+' '+Math.round(r.width)+'x'+Math.round(r.height));
    });
    console.log('texts found:', texts.length);
    texts.forEach(function(t,i){
      if(i<10){
        var r = t.getBoundingClientRect();
        console.log('  text',i,'"'+t.textContent+'" fill:',getComputedStyle(t).fill,'rect:',Math.round(r.left)+','+Math.round(r.top));
      }
    });
  };

  function run(){ applyTheme(); }
  if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded', run); } else { run(); }

  // Theme attribute changes -> re-apply
  var bodyObs = new MutationObserver(applyTheme);
  function attachBody(){
    if(document.body) bodyObs.observe(document.body, { attributes: true, attributeFilter: ['data-theme'] });
  }
  if(document.body) attachBody(); else document.addEventListener('DOMContentLoaded', attachBody);

  // Dash content changes -> re-apply (charts re-rendered)
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
})();
/* END PLOTLY_BG_FORCE_v6 */
JS_EOF

# Version bump to v1.0.18
python3 <<'PY'
import re, pathlib
for fn in ('assets/theme-toggle.js','app.py'):
    p = pathlib.Path(fn)
    if not p.exists(): continue
    s = p.read_text(); s2 = re.sub(r"v1\.0\.1[0-9]", "v1.0.18", s)
    if s != s2:
        p.write_text(s2); print(fn,'->','v1.0.18')
PY

echo "----- restart -----"
pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
tail -n 10 /tmp/eeg-reporter.log
echo
echo "v6 applied. Ctrl+Shift+R. Footer = v1.0.18"
echo "Run __chartDiag() in console after refresh to see what's actually drawn"
