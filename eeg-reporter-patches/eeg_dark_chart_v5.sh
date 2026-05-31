#!/usr/bin/env bash
# eeg_dark_chart_v5.sh
# v5: The container bg is now dark (v4 worked), but rect.bg INSIDE the SVG still
# has fill="#ffffff" overlaying the bars/text. Inspector shows:
#   - body[data-theme="dark"] .js-plotly-plot rect.bg { fill: #ffffff !important; }
#   (something in our own CSS is forcing white fill on rect.bg)
# Strategy:
#   1) Scan/strip any rect.bg white-fill rule from neurochart-theme.css
#   2) Strengthen v4 JS to also set rect.bg fill via setAttribute + style
#   3) Force bar fill colors to remain visible (don't clobber the data fills)

set -euo pipefail
cd ~/eeg-reporter

JS=assets/theme-toggle.js
CSS=assets/neurochart-theme.css
ts=$(date +%Y%m%d_%H%M%S)
cp "$JS"  "${JS}.bak.${ts}"
cp "$CSS" "${CSS}.bak.${ts}"

# 1) Hunt down any rule that sets white fill on rect.bg or .bg inside plotly
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/neurochart-theme.css')
s = p.read_text()
orig = s

# Find any rule block whose selector mentions plotly/main-svg/svg-container AND contains
# `fill: #ffffff` or `fill: white` or `background: white` - print them for visibility
suspect_pat = re.compile(
    r'([^{}]*(?:plotly|main-svg|svg-container|\.bg|rect\.bg)[^{}]*)\{([^}]*fill\s*:\s*(?:#ffffff|#fff|white)[^}]*)\}',
    re.IGNORECASE
)
matches = suspect_pat.findall(s)
print('found', len(matches), 'suspect rule(s) forcing white fill:')
for sel, body in matches:
    print('  selector:', sel.strip()[:120])
    print('  body    :', body.strip()[:120])

# Remove those rules
s = suspect_pat.sub('', s)
if s != orig:
    p.write_text(s)
    print('stripped white-fill rules from CSS')
else:
    print('no whitelist matches removed; will rely on JS')
PY

# 2) Replace the PLOTLY_BG_FORCE_v4 block with v5 (stronger, targets rect.bg explicitly)
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/theme-toggle.js')
s = p.read_text()
pat = re.compile(r'/\*\s*BEGIN PLOTLY_BG_FORCE.*?END PLOTLY_BG_FORCE\S*\s*\*/\s*', re.DOTALL)
s = pat.sub('', s)
p.write_text(s)
PY

cat >> "$JS" <<'JS_EOF'

/* BEGIN PLOTLY_BG_FORCE_v5 - 2026-05-31
   v4 dark-ified the outer SVG; v5 also forces the INTERNAL rect.bg fill.
   Inspector showed rect.bg still had fill="#ffffff !important" painting white
   over the bars/text. We aggressively override via attribute AND style. */
(function(){
  var SURFACE = '#2a3548';  // --nc-surface
  var TEXT    = '#f0f5fb';  // --nc-text
  var MUTED   = '#b8c3d6';  // --nc-text-muted
  var BORDER  = '#45526c';  // --nc-border

  function isDark(){
    return document.body && document.body.getAttribute('data-theme') === 'dark';
  }

  function clearWhite(el){
    // Remove any forced white inline styles so our values take effect
    if(el.style){
      el.style.removeProperty('background');
      el.style.removeProperty('background-color');
      el.style.removeProperty('fill');
    }
  }

  function fixPlotlyBg(){
    if(!isDark()) return;
    // Outer containers
    document.querySelectorAll('.js-plotly-plot, .plot-container, .svg-container, svg.main-svg')
      .forEach(function(el){
        el.style.setProperty('background', SURFACE, 'important');
        el.style.setProperty('background-color', SURFACE, 'important');
      });
    // Background rects INSIDE the chart SVG (the plot-area white)
    document.querySelectorAll('svg.main-svg rect.bg, .main-svg .bg, svg .bglayer rect, .bglayer path').forEach(function(r){
      r.setAttribute('fill', SURFACE);
      r.style.setProperty('fill', SURFACE, 'important');
    });
    // The xy plot area rect drawn by Plotly's cartesian layer
    document.querySelectorAll('svg.main-svg g.cartesianlayer .nsewdrag').forEach(function(r){
      // keep transparent so bars show — DO NOT fill
      r.style.setProperty('fill', 'transparent', 'important');
    });
    // Text -> light color
    document.querySelectorAll('svg.main-svg text').forEach(function(t){
      t.style.setProperty('fill', TEXT, 'important');
      t.setAttribute('fill', TEXT);
    });
    // Axis lines + tick marks
    document.querySelectorAll('svg.main-svg .xaxis path.domain, svg.main-svg .yaxis path.domain, svg.main-svg .crisp').forEach(function(l){
      l.setAttribute('stroke', MUTED);
      l.style.setProperty('stroke', MUTED, 'important');
    });
    // Grid lines
    document.querySelectorAll('svg.main-svg .gridlayer path, svg.main-svg .xgrid, svg.main-svg .ygrid').forEach(function(g){
      g.setAttribute('stroke', BORDER);
      g.style.setProperty('stroke', BORDER, 'important');
    });
  }

  function fixOnLoad(){
    if(document.readyState === 'loading'){
      document.addEventListener('DOMContentLoaded', fixPlotlyBg);
    } else {
      fixPlotlyBg();
    }
  }
  fixOnLoad();

  var bodyObs = new MutationObserver(fixPlotlyBg);
  function attachBody(){
    if(document.body){
      bodyObs.observe(document.body, { attributes: true, attributeFilter: ['data-theme'] });
    }
  }
  if(document.body) attachBody(); else document.addEventListener('DOMContentLoaded', attachBody);

  var contentObs = new MutationObserver(function(muts){
    for(var i=0;i<muts.length;i++){
      if(muts[i].addedNodes && muts[i].addedNodes.length){
        setTimeout(fixPlotlyBg, 30);
        return;
      }
    }
  });
  function attachContent(){
    var root = document.getElementById('react-entry-point') || document.body;
    if(root) contentObs.observe(root, { childList: true, subtree: true });
  }
  if(document.body) attachContent(); else document.addEventListener('DOMContentLoaded', attachContent);

  setInterval(fixPlotlyBg, 1500);
  window.__fixPlotlyBg = fixPlotlyBg;
})();
/* END PLOTLY_BG_FORCE_v5 */
JS_EOF

# 3) Version bump to v1.0.17
python3 <<'PY'
import re, pathlib
for fn in ('assets/theme-toggle.js','app.py'):
    p = pathlib.Path(fn)
    if not p.exists(): continue
    s = p.read_text(); s2 = re.sub(r"v1\.0\.1[0-9]", "v1.0.17", s)
    if s != s2:
        p.write_text(s2); print(fn,'->','v1.0.17')
PY

echo "----- restart -----"
pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
tail -n 12 /tmp/eeg-reporter.log
echo
echo "v5 applied. Ctrl+Shift+R. Footer must read EEG Reporter v1.0.17"
