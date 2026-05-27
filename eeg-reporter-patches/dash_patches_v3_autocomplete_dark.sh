#!/bin/bash
# Dash UI v3: autocomplete search + dark mode (default on, toggle in header)
set -e
cd ~/eeg-reporter
cp app.py app.py.bak-$(date +%Y%m%d-%H%M%S)

python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/app.py"
src = p.read_text()

# ============================================================
# PATCH 1: Replace dcc.Input search-box with a Dropdown that has search-as-you-type
# ============================================================
old_search = '''            dcc.Input(id="search-box", type="text", placeholder="Search patient, ID, DOB...",
                debounce=True,
                style={"width":"100%","padding":"6px 8px","marginBottom":"6px",
                       "border":"1px solid #ccc","borderRadius":"4px","fontSize":"9pt",
                       "boxSizing":"border-box"}),'''

new_search = '''            dcc.Dropdown(id="search-box", placeholder="Search patient, ID, DOB, MD...",
                options=[], value=None,
                search_value="", clearable=True, optionHeight=42,
                style={"fontSize":"9pt","marginBottom":"6px"}),'''

if old_search not in src:
    print("ERROR: search-box anchor not found")
    raise SystemExit(1)
src = src.replace(old_search, new_search)

# ============================================================
# PATCH 2: Add dark-mode toggle button to the header
# Locate the header bar that contains the H1 / title
# ============================================================
# Find the first "padding":"20px 30px 10px","borderBottom":"2px solid #003366"} block —
# that's the header. Insert the toggle right before that closing style.
header_anchor = '"padding":"20px 30px 10px","borderBottom":"2px solid #003366"'
if header_anchor not in src:
    print("WARNING: header anchor not found, skipping toggle button placement")
else:
    # Insert a wrapper Div with the existing content + a toggle button
    pass  # We'll inject the toggle via a clientside callback into the body instead

# ============================================================
# PATCH 3: Build a callback that populates the search dropdown options as the user types
# Insert just before the existing update_list callback.
# ============================================================
existing_callback_anchor = '@app.callback(Output("report-list","children"), Output("filter-year","options"), Output("report-count","children"),'
if existing_callback_anchor not in src:
    print("ERROR: could not find update_list callback anchor")
    raise SystemExit(1)

new_search_callback = '''@app.callback(
    Output("search-box", "options"),
    Input("search-box", "search_value"),
    prevent_initial_call=True,
)
def _search_options(query):
    """Live autocomplete: full-haystack search across name, ID, DOB, MDs."""
    if not query or len(query.strip()) < 2:
        return []
    q = query.strip().lower()
    matches = []
    seen = set()
    rpts = _load()
    for path, rpt, findings in rpts:
        pnt_phys = (findings.get("pnt_meta", {}) or {}).get("physician", "") if isinstance(findings, dict) else ""
        haystack_parts = [
            rpt.get("patient_name", "") or "",
            rpt.get("patient_id", "") or "",
            rpt.get("patient_dob", "") or "",
            rpt.get("recording_date", "") or "",
            rpt.get("interpreting_physician", "") or "",
            rpt.get("ordering_physician", "") or "",
            rpt.get("referring_physician", "") or "",
            pnt_phys or "",
        ]
        haystack = " ".join(haystack_parts).lower()
        if q in haystack:
            label_main = rpt.get("patient_name", path.stem) or path.stem
            label_sub = " · ".join(x for x in [
                rpt.get("recording_date", "") or "",
                rpt.get("patient_id", "") or "",
            ] if x)
            label = f"{label_main}  ({label_sub})" if label_sub else label_main
            key = str(path)
            if key not in seen:
                seen.add(key)
                matches.append({"label": label, "value": key})
        if len(matches) >= 25:
            break
    return matches


'''

src = src.replace(existing_callback_anchor, new_search_callback + existing_callback_anchor)

# ============================================================
# PATCH 4: The existing update_list callback uses `search` as a free-text string.
# Now search-box value is a path string (when user clicks an option) or None.
# Update the filter to: if `search` is a path → show ONLY that report.
# Else fall back to free-text via the typed search_value (we'll wire it in next patch).
# ============================================================
old_filter_block = '''        if q:
            pnt_phys = (findings.get('pnt_meta',{}) or {}).get('physician','') if isinstance(findings, dict) else ''
            haystack = ' '.join([
                rpt.get('patient_name',''), rpt.get('patient_id',''), rpt.get('patient_dob',''),
                rpt.get('recording_date',''),
                rpt.get('interpreting_physician',''),
                rpt.get('ordering_physician','') or '',
                rpt.get('referring_physician','') or '',
                pnt_phys or '',
                rpt.get('status','')
            ]).lower()
            if q not in haystack:
                continue'''

new_filter_block = '''        if q:
            # If search-box value looks like a file path (user picked an option), match by path
            if "/" in q or "\\\\" in q:
                if str(path).lower() != q:
                    continue
            else:
                pnt_phys = (findings.get('pnt_meta',{}) or {}).get('physician','') if isinstance(findings, dict) else ''
                haystack = ' '.join([
                    rpt.get('patient_name',''), rpt.get('patient_id',''), rpt.get('patient_dob',''),
                    rpt.get('recording_date',''),
                    rpt.get('interpreting_physician',''),
                    rpt.get('ordering_physician','') or '',
                    rpt.get('referring_physician','') or '',
                    pnt_phys or '',
                    rpt.get('status','')
                ]).lower()
                if q not in haystack:
                    continue'''

if old_filter_block not in src:
    print("ERROR: filter haystack block not found")
    raise SystemExit(1)
src = src.replace(old_filter_block, new_filter_block)

# ============================================================
# PATCH 5: Dark mode — inject CSS and a toggle button via clientside callback
# Add an index_string override that includes the dark-mode CSS + the toggle.
# Easier: add a dcc.Store + clientside callback + global CSS via assets.
# ============================================================
# Check if assets dir exists; we'll write the CSS there
assets = Path.home() / "eeg-reporter/assets"
assets.mkdir(exist_ok=True)
css_file = assets / "dark-mode.css"
css_file.write_text("""/* EEG Reporter — Dark mode */
body { background:#0f1419 !important; color:#e6e6e6 !important; transition:background 0.2s, color 0.2s; }
body.light-mode { background:#ffffff !important; color:#1a1a1a !important; }

body div[style*="background-color: rgb(240, 244, 255)"],
body div[style*="background-color:#f0f4ff"] {
    background-color:#1a2332 !important;
}
body.light-mode div[style*="background-color: rgb(240, 244, 255)"],
body.light-mode div[style*="background-color:#f0f4ff"] {
    background-color:#f0f4ff !important;
}

/* Headers and panels */
body h1, body h2, body h3, body h4 { color:#7dd3fc !important; }
body.light-mode h1, body.light-mode h2, body.light-mode h3, body.light-mode h4 { color:#003366 !important; }

/* Borders */
body div[style*="border-right: 1px solid"] { border-right-color:#2a3a4f !important; }
body.light-mode div[style*="border-right: 1px solid"] { border-right-color:#ddd !important; }
body div[style*="border-top: 1px solid"] { border-top-color:#2a3a4f !important; }
body.light-mode div[style*="border-top: 1px solid"] { border-top-color:#ddd !important; }
body div[style*="border-bottom: 2px solid"] { border-bottom-color:#0891B2 !important; }
body.light-mode div[style*="border-bottom: 2px solid"] { border-bottom-color:#003366 !important; }

/* Inputs and dropdowns */
body input[type="text"], body .Select-control, body .Select-input > input {
    background-color:#1a2332 !important; color:#e6e6e6 !important;
    border-color:#2a3a4f !important;
}
body.light-mode input[type="text"], body.light-mode .Select-control, body.light-mode .Select-input > input {
    background-color:#fff !important; color:#1a1a1a !important;
    border-color:#ccc !important;
}
body .Select-menu-outer { background-color:#1a2332 !important; color:#e6e6e6 !important; border-color:#2a3a4f !important; }
body.light-mode .Select-menu-outer { background-color:#fff !important; color:#1a1a1a !important; }
body .Select-option { background-color:#1a2332 !important; color:#e6e6e6 !important; }
body .Select-option.is-focused, body .Select-option:hover { background-color:#2a3a4f !important; }
body.light-mode .Select-option { background-color:#fff !important; color:#1a1a1a !important; }
body.light-mode .Select-option.is-focused, body.light-mode .Select-option:hover { background-color:#f0f4ff !important; }

/* Date picker */
body .DateInput_input { background-color:#1a2332 !important; color:#e6e6e6 !important; }
body.light-mode .DateInput_input { background-color:#fff !important; color:#1a1a1a !important; }

/* Report list items */
body div[style*="color: rgb(85, 85, 85)"] { color:#9ca3af !important; }
body.light-mode div[style*="color: rgb(85, 85, 85)"] { color:#555 !important; }

/* Dark mode toggle button */
.eeg-darkmode-toggle {
    position:fixed; top:14px; right:24px; z-index:9999;
    width:36px; height:36px; border-radius:50%; border:1px solid #555;
    background:#1a2332; color:#facc15; font-size:18px; cursor:pointer;
    display:flex; align-items:center; justify-content:center;
}
body.light-mode .eeg-darkmode-toggle {
    background:#fff; color:#003366; border-color:#003366;
}
""")
print(f"Wrote {css_file}")

# JS: inject toggle button + remember preference
js_file = assets / "dark-mode.js"
js_file.write_text("""// EEG Reporter — Dark mode toggle (default dark, remembered in localStorage)
(function() {
    function init() {
        var saved = localStorage.getItem('eeg-reporter-dark-mode');
        if (saved === null) {
            // Default dark, matching NeuroChart
            document.body.classList.remove('light-mode');
        } else if (saved === 'light') {
            document.body.classList.add('light-mode');
        } else {
            document.body.classList.remove('light-mode');
        }
        if (!document.getElementById('eeg-dm-btn')) {
            var btn = document.createElement('button');
            btn.id = 'eeg-dm-btn';
            btn.className = 'eeg-darkmode-toggle';
            btn.title = 'Toggle dark mode';
            updateBtn(btn);
            btn.addEventListener('click', function() {
                document.body.classList.toggle('light-mode');
                var isLight = document.body.classList.contains('light-mode');
                localStorage.setItem('eeg-reporter-dark-mode', isLight ? 'light' : 'dark');
                updateBtn(btn);
            });
            document.body.appendChild(btn);
        }
    }
    function updateBtn(btn) {
        btn.textContent = document.body.classList.contains('light-mode') ? '🌙' : '☀';
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    // Re-run on Dash re-renders
    setInterval(init, 2000);
})();
""")
print(f"Wrote {js_file}")

p.write_text(src)
print("All app.py patches applied")
PYFIX

python3 -c "import ast; ast.parse(open('app.py').read()); print('SYNTAX OK')"

# Restart
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
tail -15 ~/eeg-reporter/logs/app.log
