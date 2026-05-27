#!/usr/bin/env python3
"""Diagnose recording_date population across all EEG reports."""
import json
from pathlib import Path
from datetime import datetime

rdir = Path.home() / "eeg-reporter/reports"
files = list(rdir.glob("*.json")) + list((rdir/"signed").glob("*.json"))
print(f"Total reports: {len(files)}")

missing = empty = 0
dates = []
recent = []
for f in files:
    try:
        d = json.loads(f.read_text())
        rpt = d.get("report", {}) or {}
        findings = d.get("findings", {}) or {}
        pnt = (findings.get("pnt_meta") or {}) if isinstance(findings, dict) else {}
        rd = rpt.get("recording_date")
        mt = f.stat().st_mtime
        if rd is None:
            missing += 1
        elif not str(rd).strip():
            empty += 1
        else:
            dates.append(rd)
        recent.append((mt, f.name, rd, rpt.get("patient_name",""), pnt))
    except Exception as e:
        print(f"ERR {f.name}: {e}")

print(f"\nrecording_date NULL:      {missing}")
print(f"recording_date EMPTY:     {empty}")
print(f"recording_date POPULATED: {len(dates)}")
if dates:
    print(f"\nDate range: min={min(dates)}  max={max(dates)}")

print(f"\nTop 15 most recently MODIFIED files:")
for mt, name, rd, pn, pnt in sorted(recent, reverse=True)[:15]:
    ts = datetime.fromtimestamp(mt).strftime("%Y-%m-%d %H:%M")
    pnt_date_keys = {k: v for k, v in pnt.items() if "date" in k.lower() or "time" in k.lower()}
    print(f"  mtime={ts}  rec_date={rd!r:30s}  {name}")
    print(f"     patient={pn!r}")
    print(f"     pnt date-ish fields: {pnt_date_keys}")

print(f"\nTop 10 highest recording_date values:")
for rd in sorted(set(dates), reverse=True)[:10]:
    print(f"  {rd}")

print(f"\nFull pnt_meta keys on newest file:")
if recent:
    _, name, _, _, pnt = sorted(recent, reverse=True)[0]
    print(f"  {name}: {list(pnt.keys()) if pnt else '(empty pnt_meta)'}")
