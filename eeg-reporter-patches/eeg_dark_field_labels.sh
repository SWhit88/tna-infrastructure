#!/usr/bin/env bash
# eeg_dark_field_labels.sh
# Field labels under the chart ("HEADER FIELDS", "Patient Name", "Date of Birth", etc.)
# and similar headings are hard-coded to dark navy in the original CSS - invisible
# on dark surface in dark mode. Override to light text in dark mode only.

set -euo pipefail
cd ~/eeg-reporter

CSS=assets/neurochart-theme.css
ts=$(date +%Y%m%d_%H%M%S)
cp "$CSS" "${CSS}.bak.${ts}"

# Strip prior block if it exists (idempotent)
python3 <<'PY'
import re, pathlib
p = pathlib.Path('assets/neurochart-theme.css')
s = p.read_text()
pat = re.compile(r'/\*\s*BEGIN DARK_FIELD_LABELS.*?END DARK_FIELD_LABELS\s*\*/\s*', re.DOTALL)
s = pat.sub('', s)
p.write_text(s)
PY

# Inspect the source HTML/CSS for these labels to figure out exact selectors.
# From screenshot: "HEADER FIELDS" is a small-caps blue heading, and the field
# labels "Patient Name", "Patient ID", "Date of Birth", "Sex", "Handedness",
# "Study Date" sit above their inputs. In Dash, dcc.Input labels are usually
# html.Label or html.Div with inline color: rgb(0, 51, 102) (navy).

# Append broad-coverage dark mode rules
cat >> "$CSS" <<'CSS_EOF'

/* BEGIN DARK_FIELD_LABELS - 2026-05-31
   Field labels and section headings (HEADER FIELDS, Patient Name, etc.)
   are colored dark navy in the original markup - invisible on dark bg.
   Override to light text in dark mode. */

/* HEADER FIELDS heading and similar section headings */
[data-theme="dark"] h3,
[data-theme="dark"] h4,
[data-theme="dark"] h5,
[data-theme="dark"] .section-heading,
[data-theme="dark"] #report-detail h3,
[data-theme="dark"] #report-detail h4 {
  color: var(--nc-text) !important;
}

/* Field labels - dcc.Label, html.Label, plain div labels above inputs */
[data-theme="dark"] label,
[data-theme="dark"] .field-label,
[data-theme="dark"] #report-detail label,
[data-theme="dark"] #report-detail .field-label {
  color: var(--nc-text) !important;
}

/* Inline-style navy text (rgb(0, 51, 102)) — most common in this app.
   Use attribute selector to catch elements with inline `color: rgb(0,51,102)` */
[data-theme="dark"] [style*="color: rgb(0, 51, 102)"],
[data-theme="dark"] [style*="color:rgb(0,51,102)"],
[data-theme="dark"] [style*="color: #003366"],
[data-theme="dark"] [style*="color:#003366"] {
  color: var(--nc-text) !important;
}

/* Any plain divs that act as labels inside report-detail (catch-all). 
   Only target small text under HEADER FIELDS section. */
[data-theme="dark"] #report-detail div[style*="font-weight"],
[data-theme="dark"] #report-detail div[style*="font-size: 10pt"],
[data-theme="dark"] #report-detail div[style*="font-size:10pt"] {
  color: var(--nc-text) !important;
}

/* END DARK_FIELD_LABELS */
CSS_EOF

# Bump version v1.0.21
python3 <<'PY'
import re, pathlib
for fn in ('assets/theme-toggle.js','app.py'):
    p = pathlib.Path(fn)
    if not p.exists(): continue
    s = p.read_text(); s2 = re.sub(r"v1\.0\.2[0-9]", "v1.0.21", s)
    if s != s2:
        p.write_text(s2); print(fn,'->','v1.0.21')
PY

pkill -f 'python.*app.py' || true
sleep 2
cd ~/eeg-reporter && nohup python3 app.py > /tmp/eeg-reporter.log 2>&1 &
disown
sleep 3
tail -n 8 /tmp/eeg-reporter.log
echo
echo "Field labels patch applied. Ctrl+Shift+R. Footer = v1.0.21"
