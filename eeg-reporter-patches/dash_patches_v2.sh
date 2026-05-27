#!/bin/bash
# Dash UI v2: date range picker + sort dropdown
set -e
cd ~/eeg-reporter
cp app.py app.py.bak-$(date +%Y%m%d-%H%M%S)

python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/app.py"
src = p.read_text()

# ---------- Patch A: Add DatePickerRange + Sort dropdown to the UI ----------
old_a = '''            html.Div([
                dcc.Dropdown(id="filter-year", placeholder="Year",
                    options=[], clearable=True,
                    style={"fontSize":"9pt","flex":"1","marginRight":"4px"}),
                dcc.Dropdown(id="filter-month", placeholder="Month",
                    options=[{"label":m,"value":str(i).zfill(2)} for i,m in enumerate(
                        ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], 1)],
                    clearable=True,
                    style={"fontSize":"9pt","flex":"1"}),
            ], style={"display":"flex","marginBottom":"6px"}),
            html.Div(id="report-count", style={"fontSize":"8pt","color":"#888","marginBottom":"4px"}),'''

new_a = '''            html.Div([
                dcc.Dropdown(id="filter-year", placeholder="Year",
                    options=[], clearable=True,
                    style={"fontSize":"9pt","flex":"1","marginRight":"4px"}),
                dcc.Dropdown(id="filter-month", placeholder="Month",
                    options=[{"label":m,"value":str(i).zfill(2)} for i,m in enumerate(
                        ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], 1)],
                    clearable=True,
                    style={"fontSize":"9pt","flex":"1"}),
            ], style={"display":"flex","marginBottom":"6px"}),
            # Date range picker — filters by recording_date (YYYY-MM-DD)
            dcc.DatePickerRange(
                id="filter-date-range",
                display_format="YYYY-MM-DD",
                first_day_of_week=0,
                clearable=True,
                with_portal=False,
                style={"fontSize":"9pt","width":"100%","marginBottom":"6px"}
            ),
            # Sort dropdown
            dcc.Dropdown(
                id="sort-by",
                options=[
                    {"label":"Recording date \u2193 (newest)", "value":"date_desc"},
                    {"label":"Recording date \u2191 (oldest)", "value":"date_asc"},
                    {"label":"Patient name (A-Z)",            "value":"name_asc"},
                    {"label":"Patient name (Z-A)",            "value":"name_desc"},
                    {"label":"Status (DRAFT first)",          "value":"status_draft"},
                ],
                value="date_desc",
                clearable=False,
                style={"fontSize":"9pt","marginBottom":"6px"}
            ),
            html.Div(id="report-count", style={"fontSize":"8pt","color":"#888","marginBottom":"4px"}),'''

if old_a not in src:
    print("ERROR: Patch A target not found")
    raise SystemExit(1)
src = src.replace(old_a, new_a)

# ---------- Patch B: Add the two new Inputs to the callback signature ----------
old_b = '@app.callback(Output("report-list","children"), Output("filter-year","options"), Output("report-count","children"), Input("refresh","n_intervals"), Input("search-box","value"), Input("filter-status","value"), Input("filter-referring-md","value"), Input("filter-ordering-md","value"), Input("filter-year","value"), Input("filter-month","value"), Input("list-refresh-trigger","data"))\ndef update_list(_, search, status_filter, ref_md, ord_md, year, month, _trigger):'

new_b = '@app.callback(Output("report-list","children"), Output("filter-year","options"), Output("report-count","children"), Input("refresh","n_intervals"), Input("search-box","value"), Input("filter-status","value"), Input("filter-referring-md","value"), Input("filter-ordering-md","value"), Input("filter-year","value"), Input("filter-month","value"), Input("filter-date-range","start_date"), Input("filter-date-range","end_date"), Input("sort-by","value"), Input("list-refresh-trigger","data"))\ndef update_list(_, search, status_filter, ref_md, ord_md, year, month, date_start, date_end, sort_by, _trigger):'

if old_b not in src:
    print("ERROR: Patch B target not found")
    raise SystemExit(1)
src = src.replace(old_b, new_b)

# ---------- Patch C: Add date-range filtering + sort logic ----------
old_c = '''        if month and not (len(rec_date) >= 7 and rec_date[5:7] == month):
            continue
        if q:'''

new_c = '''        if month and not (len(rec_date) >= 7 and rec_date[5:7] == month):
            continue
        # Date range — YYYY-MM-DD lexicographic comparison works for YYYY-MM-DD format
        if date_start and rec_date and rec_date[:10] < date_start[:10]:
            continue
        if date_end and rec_date and rec_date[:10] > date_end[:10]:
            continue
        if q:'''

if old_c not in src:
    print("ERROR: Patch C target not found")
    raise SystemExit(1)
src = src.replace(old_c, new_c)

# ---------- Patch D: Apply sort just before rendering items ----------
old_d = '''    count_txt = f'{len(filtered)} of {len(rpts)} reports'
    if not filtered:
        return html.P('No matching reports.', style={'color':'#999'}), year_opts, count_txt'''

new_d = '''    # Sort filtered results
    def _sort_key(item):
        _path, rpt, _f = item
        return (rpt.get('recording_date','') or '', rpt.get('patient_name','') or '')
    sort_by = sort_by or 'date_desc'
    if sort_by == 'date_desc':
        filtered.sort(key=lambda x: (x[1].get('recording_date','') or '', x[1].get('patient_name','') or ''), reverse=True)
    elif sort_by == 'date_asc':
        filtered.sort(key=lambda x: (x[1].get('recording_date','') or '', x[1].get('patient_name','') or ''))
    elif sort_by == 'name_asc':
        filtered.sort(key=lambda x: (x[1].get('patient_name','') or '').upper())
    elif sort_by == 'name_desc':
        filtered.sort(key=lambda x: (x[1].get('patient_name','') or '').upper(), reverse=True)
    elif sort_by == 'status_draft':
        # DRAFT first, then by recording date desc within each status
        filtered.sort(key=lambda x: (
            0 if 'DRAFT' in (x[1].get('status','') or '').upper() else 1,
            -(int((x[1].get('recording_date','') or '1900-01-01').replace('-','')[:8]) if (x[1].get('recording_date','') or '').replace('-','')[:8].isdigit() else 0)
        ))
    count_txt = f'{len(filtered)} of {len(rpts)} reports'
    if not filtered:
        return html.P('No matching reports.', style={'color':'#999'}), year_opts, count_txt'''

if old_d not in src:
    print("ERROR: Patch D target not found")
    raise SystemExit(1)
src = src.replace(old_d, new_d)

p.write_text(src)
print("All 4 patches applied")
PYFIX

python3 -c "import ast; ast.parse(open('app.py').read()); print('SYNTAX OK')"

# Restart Dash
tmux kill-session -t eeg-reporter 2>/dev/null || true
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
tail -8 logs/app.log
