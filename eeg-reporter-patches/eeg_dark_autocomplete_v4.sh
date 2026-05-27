#!/bin/bash
# Clean, conservative install of:
#   1. Dark mode (default ON, toggle button, localStorage persistence)
#   2. Autocomplete dropdown under the search box (one-way callback)
#
# Both touch app.py only. Both restorable from .bak. No layout or callback wiring
# changes other than the additive bits below.
set -e
cd ~/eeg-reporter

# ---------------------------------------------------------------------------
# 0. Sanity: backup app.py
# ---------------------------------------------------------------------------
TS=$(date +%Y%m%d-%H%M%S)
cp app.py app.py.bak-${TS}-pre-dark-ac
echo "Backed up app.py to app.py.bak-${TS}-pre-dark-ac"

mkdir -p assets

# ---------------------------------------------------------------------------
# 1. Write assets/dark-mode.css  — overrides for dark backgrounds
# ---------------------------------------------------------------------------
cat > assets/dark-mode.css <<'CSS'
/* TNA EEG Reporter dark mode — aligned with NeuroChart navy/teal scheme */
:root[data-theme="dark"] {
  --tna-bg:        #0f172a;   /* slate-900 */
  --tna-bg-panel:  #1e293b;   /* slate-800 */
  --tna-bg-input:  #334155;   /* slate-700 */
  --tna-fg:        #e2e8f0;   /* slate-200 */
  --tna-fg-muted:  #94a3b8;   /* slate-400 */
  --tna-accent:    #0891b2;   /* teal-600 */
  --tna-accent-2:  #1e3a5f;   /* navy */
  --tna-border:    #475569;   /* slate-600 */
}
:root[data-theme="dark"] body,
:root[data-theme="dark"] {
  background-color: var(--tna-bg) !important;
  color: var(--tna-fg) !important;
}
:root[data-theme="dark"] .Select-control,
:root[data-theme="dark"] input,
:root[data-theme="dark"] textarea,
:root[data-theme="dark"] select {
  background-color: var(--tna-bg-input) !important;
  color: var(--tna-fg) !important;
  border-color: var(--tna-border) !important;
}
:root[data-theme="dark"] table {
  color: var(--tna-fg) !important;
  background-color: var(--tna-bg-panel) !important;
}
:root[data-theme="dark"] th {
  background-color: var(--tna-accent-2) !important;
  color: #fff !important;
  border-color: var(--tna-border) !important;
}
:root[data-theme="dark"] td {
  border-color: var(--tna-border) !important;
}
:root[data-theme="dark"] tr:nth-child(even) td {
  background-color: #1a2540 !important;
}
:root[data-theme="dark"] a { color: #7dd3fc !important; }
:root[data-theme="dark"] button,
:root[data-theme="dark"] .btn,
:root[data-theme="dark"] input[type="submit"] {
  background-color: var(--tna-accent) !important;
  color: #fff !important;
  border-color: var(--tna-accent) !important;
}
/* Autocomplete dropdown */
#search-suggest {
  position: absolute;
  z-index: 9999;
  background: #fff;
  border: 1px solid #cbd5e1;
  border-top: none;
  max-height: 280px;
  overflow-y: auto;
  width: 100%;
  box-shadow: 0 8px 20px rgba(0,0,0,0.12);
  border-radius: 0 0 6px 6px;
}
:root[data-theme="dark"] #search-suggest {
  background: var(--tna-bg-panel);
  border-color: var(--tna-border);
  box-shadow: 0 8px 20px rgba(0,0,0,0.6);
}
#search-suggest .suggest-row {
  padding: 8px 12px;
  cursor: pointer;
  border-bottom: 1px solid #f1f5f9;
  font-size: 0.92rem;
}
:root[data-theme="dark"] #search-suggest .suggest-row {
  border-bottom-color: #334155;
  color: var(--tna-fg);
}
#search-suggest .suggest-row:hover {
  background: #e0f2fe;
}
:root[data-theme="dark"] #search-suggest .suggest-row:hover {
  background: #1e3a5f;
}
.suggest-row .suggest-meta {
  color: #64748b;
  font-size: 0.82rem;
  margin-left: 6px;
}
:root[data-theme="dark"] .suggest-row .suggest-meta {
  color: var(--tna-fg-muted);
}
/* Theme toggle button */
#theme-toggle {
  position: fixed;
  top: 12px;
  right: 14px;
  z-index: 10000;
  background: var(--tna-bg-panel, #1e293b);
  color: var(--tna-fg, #e2e8f0);
  border: 1px solid var(--tna-border, #475569);
  border-radius: 6px;
  padding: 6px 10px;
  font-size: 0.9rem;
  cursor: pointer;
}
:root:not([data-theme="dark"]) #theme-toggle {
  background: #1e3a5f;
  color: #fff;
  border-color: #1e3a5f;
}
CSS
echo "Wrote assets/dark-mode.css"

# ---------------------------------------------------------------------------
# 2. Write assets/dark-mode.js  — default-to-dark + toggle + autocomplete clicks
# ---------------------------------------------------------------------------
cat > assets/dark-mode.js <<'JS'
// TNA EEG Reporter — dark mode toggle + autocomplete row clicks
(function() {
  // ---- Dark mode --------------------------------------------------------
  function applyTheme(t) {
    document.documentElement.setAttribute("data-theme", t);
    var btn = document.getElementById("theme-toggle");
    if (btn) btn.textContent = (t === "dark" ? "Light mode" : "Dark mode");
  }
  function currentTheme() {
    return localStorage.getItem("eeg-theme") || "dark";  // default dark
  }
  function toggleTheme() {
    var t = currentTheme() === "dark" ? "light" : "dark";
    localStorage.setItem("eeg-theme", t);
    applyTheme(t);
  }
  // Apply on load
  applyTheme(currentTheme());

  // Inject toggle button once DOM ready
  function injectToggle() {
    if (document.getElementById("theme-toggle")) return;
    var btn = document.createElement("button");
    btn.id = "theme-toggle";
    btn.textContent = (currentTheme() === "dark" ? "Light mode" : "Dark mode");
    btn.onclick = toggleTheme;
    document.body.appendChild(btn);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", injectToggle);
  } else {
    injectToggle();
  }
  // Re-apply after Dash redraws (which can wipe data-theme on the html el)
  var mo = new MutationObserver(function() {
    if (document.documentElement.getAttribute("data-theme") !== currentTheme()) {
      applyTheme(currentTheme());
    }
    injectToggle();
  });
  mo.observe(document.documentElement, { attributes: true, childList: true, subtree: false });

  // ---- Autocomplete row click handler -----------------------------------
  // When user clicks a .suggest-row, copy its data-stem attribute into the
  // search box and dispatch an input event so Dash sees the change.
  document.addEventListener("click", function(ev) {
    var row = ev.target.closest(".suggest-row");
    if (!row) return;
    var stem = row.getAttribute("data-stem");
    var box  = document.getElementById("search-box");
    if (stem && box) {
      // Native setter so React/Dash registers the change
      var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
      setter.call(box, stem);
      box.dispatchEvent(new Event("input", { bubbles: true }));
      // Hide the suggest panel
      var sg = document.getElementById("search-suggest");
      if (sg) sg.innerHTML = "";
    }
  });

  // ---- Hide autocomplete on outside-click -------------------------------
  document.addEventListener("click", function(ev) {
    if (ev.target.closest("#search-suggest") || ev.target.id === "search-box") return;
    var sg = document.getElementById("search-suggest");
    if (sg) sg.innerHTML = "";
  });
})();
JS
echo "Wrote assets/dark-mode.js"

# ---------------------------------------------------------------------------
# 3. Patch app.py — additive only:
#    a) add a <div id="search-suggest"> right after the search-box in the layout
#    b) add ONE new callback:  Input("search-box","value") -> Output("search-suggest","children")
# ---------------------------------------------------------------------------
python3 - <<'PY'
import re, ast
from pathlib import Path
p = Path.home() / "eeg-reporter/app.py"
src = p.read_text()

# --- 3a. Insert <div id="search-suggest"> after the dcc.Input(id="search-box") ---
if 'id="search-suggest"' in src:
    print("search-suggest div already present in layout — leaving alone")
else:
    # Find the search-box Input definition. Look for the closing parenthesis of
    # the dcc.Input(...) call where id="search-box" appears. We'll insert a
    # html.Div with id="search-suggest" immediately after it.
    pat = re.compile(
        r'(dcc\.Input\([^)]*id="search-box"[^)]*\))',
        re.DOTALL,
    )
    m = pat.search(src)
    if not m:
        # Try with single quotes
        pat = re.compile(r"(dcc\.Input\([^)]*id='search-box'[^)]*\))", re.DOTALL)
        m = pat.search(src)
    if not m:
        raise SystemExit("ERROR: could not find dcc.Input(id='search-box') to anchor suggest div")
    inj = m.group(1) + ', html.Div(id="search-suggest")'
    src = src[:m.start()] + inj + src[m.end():]
    print("Inserted html.Div(id='search-suggest') after the search-box Input")

# --- 3b. Append the autocomplete callback at the end of the file ---
if "search-suggest" in src and "Output(\"search-suggest\"" in src:
    print("search-suggest callback already present")
else:
    callback = '''

# --- Autocomplete suggestions for the search box -----------------------------
# One-way: as the user types, generate clickable suggestion rows. The JS in
# assets/dark-mode.js handles row clicks by copying data-stem into search-box.
@app.callback(
    Output("search-suggest", "children"),
    Input("search-box", "value"),
    prevent_initial_call=True,
)
def _autocomplete(q):
    from dash import html
    if not q or len(q.strip()) < 2:
        return ""
    qn = q.strip().lower()
    try:
        reports = _list_reports()  # uses the existing helper that powers the table
    except Exception:
        return ""
    rows = []
    for r in reports:
        hay = " ".join(str(r.get(k, "")) for k in (
            "stem", "patient_name", "patient_id", "patient_dob",
            "referring_physician", "ordering_physician",
        )).lower()
        if qn in hay:
            label = r.get("patient_name") or r.get("stem", "")
            meta_bits = [r.get("stem", ""), r.get("patient_id", ""), r.get("patient_dob", "")]
            meta = " · ".join([b for b in meta_bits if b])
            rows.append(html.Div(
                [
                    html.Span(label),
                    html.Span(" " + meta, className="suggest-meta"),
                ],
                className="suggest-row",
                **{"data-stem": r.get("stem", "")},
            ))
        if len(rows) >= 12:
            break
    return rows
'''
    src = src.rstrip() + callback + "\n"
    print("Appended autocomplete callback")

p.write_text(src)
ast.parse(p.read_text())
print("app.py PARSES OK")
PY

# ---------------------------------------------------------------------------
# 4. Restart watcher
# ---------------------------------------------------------------------------
tmux kill-session -t eeg-reporter 2>/dev/null || true
sleep 2
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6

echo "------ last 15 log lines ------"
tail -15 ~/eeg-reporter/logs/app.log
echo
echo "Open http://100.113.163.65:8060 — hard-reload (Ctrl+Shift+R)."
echo "  - Page should load dark by default; toggle is top-right."
echo "  - Type 2+ chars in the search box -> suggestion dropdown appears."
echo "  - Click a row -> search-box fills with that stem -> table filters."
