#!/bin/bash
# Dash UI v3 FIX: roll back the broken dropdown-overload, restore the original
# dcc.Input search, and add autocomplete as a SEPARATE suggestions panel below
# the input. Keeps the original update_list callback wiring intact.
#
# Safe to re-run: idempotent. Always restores from the latest .bak first.
set -e
cd ~/eeg-reporter

# -------- 1. Roll back to the latest .bak --------
LATEST_BAK=$(ls -1t app.py.bak-* 2>/dev/null | head -1 || true)
if [ -z "$LATEST_BAK" ]; then
  echo "ERROR: no app.py.bak-* found. Cannot safely roll back."
  exit 1
fi
echo "Restoring app.py from $LATEST_BAK"
cp "$LATEST_BAK" app.py
cp app.py app.py.bak-$(date +%Y%m%d-%H%M%S)-pre-v3fix

python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/app.py"
src = p.read_text()

# ============================================================
# Confirm the ORIGINAL dcc.Input search-box is back in place
# ============================================================
input_anchor = 'dcc.Input(id="search-box"'
if input_anchor not in src:
    raise SystemExit("ERROR: expected the original dcc.Input search-box back after rollback")

# ============================================================
# PATCH A: Add a sibling suggestions Dropdown (id='search-suggest')
# right after the search-box block.
# ============================================================
# Find the closing of the dcc.Input(...) for the search-box (the entire tuple).
import re
m = re.search(
    r'(dcc\.Input\(id="search-box".*?\}\),)',
    src, re.DOTALL)
if not m:
    raise SystemExit("ERROR: could not locate dcc.Input(id='search-box', ...) block")

original_input_block = m.group(1)
sibling = original_input_block + '''
            dcc.Dropdown(id="search-suggest", options=[], value=None,
                placeholder="Live matches will appear here as you type...",
                clearable=True, optionHeight=42,
                style={"fontSize":"9pt","marginBottom":"6px","display":"none"}),'''

if 'id="search-suggest"' not in src:
    src = src.replace(original_input_block, sibling, 1)
    print("Inserted search-suggest sibling Dropdown")
else:
    print("search-suggest already present, skipping")

# ============================================================
# PATCH B: New callback that populates search-suggest options based on
# typing in the search-box. Uses Input("search-box","value") which the
# existing update_list also reads — this is fine, Dash supports multiple
# callbacks on the same input as long as outputs differ.
# ============================================================
callback_code = '''

@app.callback(
    Output("search-suggest", "options"),
    Output("search-suggest", "style"),
    Input("search-box", "value"),
    prevent_initial_call=True,
)
def _eeg_search_suggest(query):
    """Live autocomplete suggestions. Shows up to 25 full-haystack matches."""
    hidden = {"fontSize":"9pt","marginBottom":"6px","display":"none"}
    visible = {"fontSize":"9pt","marginBottom":"6px","display":"block"}
    if not query or len(query.strip()) < 2:
        return [], hidden
    try:
        q = query.strip().lower()
        out = []
        seen = set()
        for path, rpt, findings in _load():
            pnt_phys = ""
            if isinstance(findings, dict):
                pm = findings.get("pnt_meta", {}) or {}
                pnt_phys = pm.get("physician", "") or ""
            parts = [
                str(rpt.get("patient_name", "") or ""),
                str(rpt.get("patient_id", "") or ""),
                str(rpt.get("patient_dob", "") or ""),
                str(rpt.get("recording_date", "") or ""),
                str(rpt.get("interpreting_physician", "") or ""),
                str(rpt.get("ordering_physician", "") or ""),
                str(rpt.get("referring_physician", "") or ""),
                str(pnt_phys),
            ]
            hay = " ".join(parts).lower()
            if q in hay:
                name = rpt.get("patient_name", "") or path.stem
                sub_bits = [x for x in [
                    rpt.get("recording_date", "") or "",
                    rpt.get("patient_id", "") or "",
                ] if x]
                label = f"{name}  ({' · '.join(sub_bits)})" if sub_bits else name
                key = str(path)
                if key not in seen:
                    seen.add(key)
                    out.append({"label": label, "value": key})
            if len(out) >= 25:
                break
        return out, (visible if out else hidden)
    except Exception as e:
        # Never let autocomplete break the page
        import traceback
        print("search-suggest error:", e)
        traceback.print_exc()
        return [], hidden


@app.callback(
    Output("search-box", "value"),
    Input("search-suggest", "value"),
    prevent_initial_call=True,
)
def _eeg_search_suggest_pick(picked):
    """When user clicks a suggestion, populate search-box with the patient name
    so the existing update_list callback can filter to that record."""
    if not picked:
        from dash import no_update
        return no_update
    # picked is a path string; resolve patient name from the JSON
    try:
        import json
        from pathlib import Path as _P
        with open(picked) as f:
            data = json.load(f)
        rpt = data.get("report", data)
        return rpt.get("patient_name", "") or ""
    except Exception:
        from dash import no_update
        return no_update

'''

# Insert the new callback code right before the existing update_list callback.
existing_callback_anchor = '@app.callback(Output("report-list","children"), Output("filter-year","options"), Output("report-count","children"),'
if existing_callback_anchor not in src:
    raise SystemExit("ERROR: could not find update_list callback anchor")

if "_eeg_search_suggest" not in src:
    src = src.replace(existing_callback_anchor, callback_code + existing_callback_anchor, 1)
    print("Inserted _eeg_search_suggest callbacks")
else:
    print("_eeg_search_suggest already present, skipping")

# ============================================================
# PATCH C: Ensure assets/dark-mode.css and dark-mode.js exist (idempotent).
# The previous v3 already wrote these — keep them.
# ============================================================
assets = Path.home() / "eeg-reporter/assets"
assets.mkdir(exist_ok=True)
css_file = assets / "dark-mode.css"
js_file = assets / "dark-mode.js"
if not css_file.exists():
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

body h1, body h2, body h3, body h4 { color:#7dd3fc !important; }
body.light-mode h1, body.light-mode h2, body.light-mode h3, body.light-mode h4 { color:#003366 !important; }

body div[style*="border-right: 1px solid"] { border-right-color:#2a3a4f !important; }
body.light-mode div[style*="border-right: 1px solid"] { border-right-color:#ddd !important; }
body div[style*="border-top: 1px solid"] { border-top-color:#2a3a4f !important; }
body.light-mode div[style*="border-top: 1px solid"] { border-top-color:#ddd !important; }
body div[style*="border-bottom: 2px solid"] { border-bottom-color:#0891B2 !important; }
body.light-mode div[style*="border-bottom: 2px solid"] { border-bottom-color:#003366 !important; }

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

body .DateInput_input { background-color:#1a2332 !important; color:#e6e6e6 !important; }
body.light-mode .DateInput_input { background-color:#fff !important; color:#1a1a1a !important; }

body div[style*="color: rgb(85, 85, 85)"] { color:#9ca3af !important; }
body.light-mode div[style*="color: rgb(85, 85, 85)"] { color:#555 !important; }

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
else:
    print(f"{css_file} already exists, leaving as-is")

if not js_file.exists():
    js_file.write_text("""// EEG Reporter — Dark mode toggle (default dark, remembered in localStorage)
(function() {
    function init() {
        var saved = localStorage.getItem('eeg-reporter-dark-mode');
        if (saved === null) {
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
    setInterval(init, 2000);
})();
""")
    print(f"Wrote {js_file}")
else:
    print(f"{js_file} already exists, leaving as-is")

p.write_text(src)
print("All v3 FIX patches applied")
PYFIX

python3 -c "import ast; ast.parse(open('app.py').read()); print('SYNTAX OK')"

# -------- 2. Restart cleanly --------
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
echo "------ last 20 log lines ------"
tail -20 ~/eeg-reporter/logs/app.log
