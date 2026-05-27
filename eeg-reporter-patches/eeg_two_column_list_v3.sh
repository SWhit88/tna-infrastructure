#!/bin/bash
# v3: Same as v2 but with correct sanity-check escaping.
# v2 aborted because the safety check string literal contained `\n` as two
# chars instead of a real newline. Fix: use simple `in` checks without `\n`.
set -e
cd ~/eeg-reporter

TS=$(date +%Y%m%d-%H%M%S)
cp app.py app.py.bak-${TS}-pre-two-column-v3
echo "[*] Backup: app.py.bak-${TS}-pre-two-column-v3"

python3 <<'PY'
import re, sys, ast
from pathlib import Path

p = Path("app.py")
src = p.read_text()
lines = src.split("\n")

# Find start: line beginning with @app.callback(Output("report-list"
start_idx = None
for i, ln in enumerate(lines):
    if ln.startswith('@app.callback(Output("report-list"'):
        start_idx = i
        break
if start_idx is None:
    print("FATAL: anchor 1 not found", file=sys.stderr); sys.exit(2)

# Find end: line beginning with "HEADER_FIELDS = ["
header_idx = None
for j in range(start_idx + 1, len(lines)):
    if lines[j].startswith("HEADER_FIELDS = ["):
        header_idx = j
        break
if header_idx is None:
    print("FATAL: anchor 2 not found", file=sys.stderr); sys.exit(3)

old_block = lines[start_idx:header_idx]
print(f"[*] Replacing lines {start_idx+1}..{header_idx} ({len(old_block)} lines)")
if not any("def update_list(" in ln for ln in old_block):
    print("FATAL: block doesn't contain def update_list", file=sys.stderr); sys.exit(4)

NEW = '''@app.callback(Output("report-list","children"), Output("filter-year","options"), Output("report-count","children"), Input("refresh","n_intervals"), Input("search-box","value"), Input("filter-status","value"), Input("filter-referring-md","value"), Input("filter-ordering-md","value"), Input("filter-year","value"), Input("filter-month","value"), Input("filter-date-range","start_date"), Input("filter-date-range","end_date"), Input("sort-by","value"), Input("list-refresh-trigger","data"))
def update_list(_, search, status_filter, ref_md, ord_md, year, month, date_start, date_end, sort_by, _trigger):
    rpts = _load()
    years = sorted({(rpt.get('recording_date','') or '')[:4] for _p,rpt,_f in rpts
                    if rpt.get('recording_date','') and len(rpt.get('recording_date',''))>=4}, reverse=True)
    year_opts = [{'label': y, 'value': y} for y in years if y]
    ref_q = (ref_md or '').strip().lower()
    ord_q = (ord_md or '').strip().lower()
    q = (search or '').strip().lower()
    filtered = []
    for path, rpt, findings in rpts:
        if status_filter and status_filter.upper() not in rpt.get('status','').upper():
            continue
        if ref_q and ref_q not in (rpt.get('referring_physician','') or '').lower():
            continue
        if ord_q and ord_q not in (rpt.get('ordering_physician','') or '').lower() \\
                    and ord_q not in ((findings.get('pnt_meta',{}) or {}).get('physician','') or '').lower():
            continue
        rec_date = rpt.get('recording_date','') or ''
        if year and not rec_date.startswith(year):
            continue
        if month and not (len(rec_date) >= 7 and rec_date[5:7] == month):
            continue
        if date_start and rec_date and rec_date[:10] < date_start[:10]:
            continue
        if date_end and rec_date and rec_date[:10] > date_end[:10]:
            continue
        if q:
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
                continue
        filtered.append((path, rpt, findings))

    def _date_key(rpt):
        return (rpt.get('recording_date','') or '', rpt.get('patient_name','') or '')
    def _name_key(rpt):
        return (rpt.get('patient_name','') or '').upper()
    sort_by = sort_by or 'date_desc'
    if sort_by == 'date_desc':
        filtered.sort(key=lambda x: _date_key(x[1]), reverse=True)
    elif sort_by == 'date_asc':
        filtered.sort(key=lambda x: _date_key(x[1]))
    elif sort_by == 'name_asc':
        filtered.sort(key=lambda x: _name_key(x[1]))
    elif sort_by == 'name_desc':
        filtered.sort(key=lambda x: _name_key(x[1]), reverse=True)
    elif sort_by == 'status_draft':
        filtered.sort(key=lambda x: _date_key(x[1]), reverse=True)

    count_txt = f'{len(filtered)} of {len(rpts)} reports'

    drafts = []
    signed_list = []
    for path, rpt, _f in filtered:
        st = (rpt.get('status','') or '').upper()
        if 'DRAFT' in st or st == '' or st == 'PENDING':
            drafts.append((path, rpt))
        else:
            signed_list.append((path, rpt))

    drafts.sort(key=lambda x: x[1].get('recording_date','') or '', reverse=True)
    signed_list.sort(key=lambda x: x[1].get('recording_date','') or '', reverse=True)

    def _card(path, rpt, is_signed):
        st = rpt.get('status','DRAFT') or 'DRAFT'
        color = '#007700' if is_signed else '#cc6600'
        border_left = '#006600' if is_signed else '#1e3a5f'
        return html.Div([
            html.Div(rpt.get('patient_name', path.stem),
                     style={'fontWeight':'bold','fontSize':'10pt'}),
            html.Div(rpt.get('recording_date',''),
                     style={'color':'#555','fontSize':'9pt'}),
            html.Div(rpt.get('patient_dob',''),
                     style={'color':'#777','fontSize':'8pt'}),
            html.Div(st, style={'color':color,'fontSize':'8pt','marginTop':'2px'}),
        ], id={'type':'report-item','index':str(path)}, n_clicks=0,
            style={'padding':'8px 10px','margin':'4px 0','cursor':'pointer',
                   'border':'1px solid #ddd','borderLeft':f'4px solid {border_left}',
                   'borderRadius':'4px','backgroundColor':'#ffffff'})

    if not filtered:
        return html.P('No matching reports.', style={'color':'#999'}), year_opts, count_txt

    left_header = html.Div([
        html.Span('Drafts (Unsigned)',
                  style={'fontWeight':'bold','fontSize':'10pt','color':'#1e3a5f'}),
        html.Span(f'  {len(drafts)}',
                  style={'color':'#6b7a90','fontSize':'9pt','marginLeft':'4px'}),
    ], style={'marginBottom':'6px','paddingBottom':'4px',
              'borderBottom':'2px solid #1e3a5f'})

    if drafts:
        left_col_children = [left_header] + [_card(p, r, False) for p, r in drafts]
    else:
        left_col_children = [left_header,
            html.P('None.', style={'color':'#999','fontSize':'9pt','fontStyle':'italic'})]
    left_col = html.Div(left_col_children,
                        style={'flex':'1','minWidth':'0','paddingRight':'6px'})

    right_header = html.Div([
        html.Span('Finalized',
                  style={'fontWeight':'bold','fontSize':'10pt','color':'#006600'}),
        html.Span(f'  {len(signed_list)}',
                  style={'color':'#6b7a90','fontSize':'9pt','marginLeft':'4px'}),
    ], style={'marginBottom':'6px','paddingBottom':'4px',
              'borderBottom':'2px solid #006600'})

    if signed_list:
        right_col_children = [right_header] + [_card(p, r, True) for p, r in signed_list]
    else:
        right_col_children = [right_header,
            html.P('None.', style={'color':'#999','fontSize':'9pt','fontStyle':'italic'})]
    right_col = html.Div(right_col_children,
                         style={'flex':'1','minWidth':'0','paddingLeft':'6px',
                                'borderLeft':'1px solid #d6dde6'})

    two_col = html.Div([left_col, right_col],
                       style={'display':'flex','flexDirection':'row','gap':'8px','width':'100%'})

    return two_col, year_opts, count_txt

# --- Editable detail pane + save/sign flow ---

'''

new_lines = NEW.split("\n")
if new_lines and new_lines[-1] == "":
    new_lines = new_lines[:-1]

patched_lines = lines[:start_idx] + new_lines + lines[header_idx:]
new_src = "\n".join(patched_lines)

# AST-check
try:
    ast.parse(new_src)
except SyntaxError as e:
    print(f"FATAL: AST parse failed: {e}", file=sys.stderr); sys.exit(5)

# Sanity (fixed checks — no escaped backslashes!)
if "ALL_EDITS = HEADER_FIELDS" not in new_src:
    print("FATAL: ALL_EDITS line missing after patch", file=sys.stderr); sys.exit(6)
if "def _resolve_report_path(" not in new_src:
    print("FATAL: _resolve_report_path missing after patch", file=sys.stderr); sys.exit(7)
if "HEADER_FIELDS = [" not in new_src:
    print("FATAL: HEADER_FIELDS missing after patch", file=sys.stderr); sys.exit(8)
if "_SAVE_STATES = [dash.State" not in new_src:
    print("FATAL: _SAVE_STATES missing after patch", file=sys.stderr); sys.exit(9)

p.write_text(new_src)
print(f"[+] Patched. New file size: {len(new_src)} chars")
PY

echo
echo "[*] Restarting eeg-reporter..."
pkill -f "python3.*main.py" 2>/dev/null || true
sleep 2
nohup python3 ~/eeg-reporter/main.py > ~/eeg-reporter/logs/app.log 2>&1 &
sleep 3

echo
echo "[*] Health check:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8060/ || true
echo
echo "[*] Tail of app.log (last 15 lines):"
tail -n 15 ~/eeg-reporter/logs/app.log
echo
echo "[*] Verify critical anchors still present:"
grep -n "^HEADER_FIELDS \|^ALL_EDITS \|^def _resolve_report_path\|^def update_list\|^_SAVE_STATES " ~/eeg-reporter/app.py
echo
echo "[✓] Done. Hard-reload the dashboard (Ctrl+Shift+R)."
