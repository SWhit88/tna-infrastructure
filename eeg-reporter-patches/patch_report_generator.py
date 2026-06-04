#!/usr/bin/env python3
"""
Patch report_generator.py to fix Ollama truncation/parse bugs discovered 2026-06-04.

Changes:
  1. num_predict: 1024 -> 2048 (truncation safety)
  2. Add format: "json" to force structured output
  3. Improve _parse_json: strip markdown fences fully, attempt JSON repair on truncation,
     log raw response when parse fails, tag _source="ollama-malformed" when fallback hit

Usage: python3 patch_report_generator.py [--apply]
       Without --apply, prints diff only. With --apply, writes file and creates .bak.
"""
import re
import sys
from pathlib import Path
import shutil
import datetime

TARGET = Path("/home/leige/eeg-reporter/report_generator.py")

OLD_GENERATE = '''def generate(findings: dict) -> dict:
    prompt = _build_prompt(findings)
    try:
        resp = requests.post(f"{OLLAMA_HOST}/api/generate",
            json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False,
                  "system": SYSTEM_PROMPT, "options": {"temperature": 0.2, "num_predict": 1024}},
            timeout=OLLAMA_TIMEOUT)
        resp.raise_for_status()
        report = _parse_json(resp.json().get("response",""))
        report["_source"] = "ollama"; report["_model"] = OLLAMA_MODEL
    except Exception as exc:
        log.warning("Ollama unavailable (%s), using template", exc)
        report = _template(findings); report["_source"] = "template"
    report.update(_meta(findings))
    return report'''

NEW_GENERATE = '''def generate(findings: dict) -> dict:
    prompt = _build_prompt(findings)
    try:
        resp = requests.post(f"{OLLAMA_HOST}/api/generate",
            json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False,
                  "system": SYSTEM_PROMPT, "format": "json",
                  "options": {"temperature": 0.2, "num_predict": 2048}},
            timeout=OLLAMA_TIMEOUT)
        resp.raise_for_status()
        raw = resp.json().get("response","")
        report = _parse_json(raw)
        if report.get("_parse_failed"):
            log.error("Ollama parse failed for prompt-len=%d resp-len=%d raw[:300]=%r",
                      len(prompt), len(raw), raw[:300])
            report["_source"] = "ollama-malformed"
        else:
            report["_source"] = "ollama"
        report["_model"] = OLLAMA_MODEL
    except Exception as exc:
        log.warning("Ollama unavailable (%s), using template", exc)
        report = _template(findings); report["_source"] = "template"
    report.update(_meta(findings))
    return report'''

OLD_PARSE = '''def _parse_json(text):
    text = re.sub(r"```(?:json)?","",text).strip()
    m = re.search(r"\\{.*\\}",text,re.DOTALL)
    if m:
        try: return json.loads(m.group())
        except: pass
    return {"clinical_history":"See automated data.",
            "technical_description":"See automated data.",
            "findings": text[:2000] or "Report generation failed.",
            "impression":"Physician review required.",
            "clinical_correlation":"Physician review required."}'''

NEW_PARSE = '''def _parse_json(text):
    # Strip markdown code fences (opening and closing)
    text = re.sub(r"^\\s*```(?:json)?\\s*", "", text)
    text = re.sub(r"\\s*```\\s*$", "", text).strip()
    # Try whole text as JSON first (format=json mode returns clean JSON)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Fallback: extract braced region
    m = re.search(r"\\{.*\\}", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except json.JSONDecodeError:
            pass
    # Last resort: attempt to repair truncated JSON by closing strings/braces
    repaired = _attempt_json_repair(text)
    if repaired is not None:
        try:
            return json.loads(repaired)
        except json.JSONDecodeError:
            pass
    return {"clinical_history": "See automated data.",
            "technical_description": "See automated data.",
            "findings": text[:2000] or "Report generation failed.",
            "impression": "Physician review required.",
            "clinical_correlation": "Physician review required.",
            "_parse_failed": True}


def _attempt_json_repair(text):
    """Attempt to repair a truncated JSON object by closing the open string and braces."""
    # Find the leading {
    start = text.find("{")
    if start < 0:
        return None
    s = text[start:]
    # If it already ends with }, no repair needed (handled above)
    if s.rstrip().endswith("}"):
        return None
    # Walk forward tracking string state and brace depth
    in_str = False
    escape = False
    depth = 0
    last_complete = -1
    for i, ch in enumerate(s):
        if escape:
            escape = False
            continue
        if ch == "\\\\":
            escape = True
            continue
        if ch == \'"\':
            in_str = not in_str
            continue
        if in_str:
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                last_complete = i
                break
        elif ch == "," and depth == 1:
            last_complete = i
    if last_complete < 0:
        # No complete key:value pair — give up
        return None
    # Truncate at last_complete, close any open string, close braces
    repaired = s[:last_complete]
    # Drop trailing comma if present
    repaired = repaired.rstrip().rstrip(",")
    # If we\'re currently inside a string, close it
    if in_str:
        repaired += \'"\'
    # Close to depth 0
    repaired += "}" * max(depth, 1)
    return repaired'''


def main():
    if not TARGET.exists():
        sys.exit(f"Target not found: {TARGET}")
    src = TARGET.read_text()

    if OLD_GENERATE not in src:
        print("[!] OLD_GENERATE block not found — file may already be patched or differs.")
        sys.exit(1)
    if OLD_PARSE not in src:
        print("[!] OLD_PARSE block not found — file may already be patched or differs.")
        sys.exit(1)

    new_src = src.replace(OLD_GENERATE, NEW_GENERATE).replace(OLD_PARSE, NEW_PARSE)

    apply = "--apply" in sys.argv
    if not apply:
        print("=" * 60)
        print("DRY RUN — no changes written. Pass --apply to commit.")
        print("=" * 60)
        print(f"Original size: {len(src)} chars")
        print(f"New size:      {len(new_src)} chars")
        print(f"Net diff:      {len(new_src) - len(src):+d} chars")
        print()
        print("Changes:")
        print("  1. generate(): num_predict 1024 -> 2048")
        print("  2. generate(): added format='json' to force structured output")
        print("  3. generate(): logs raw response when parse fails")
        print("  4. generate(): tags _source='ollama-malformed' on parse failure")
        print("  5. _parse_json: strips both opening AND closing code fences")
        print("  6. _parse_json: tries whole-text json.loads first (format=json case)")
        print("  7. _parse_json: adds _attempt_json_repair() for truncated responses")
        print("  8. _parse_json: tags _parse_failed=True on fallback")
        return

    bak = TARGET.with_suffix(f".py.bak.{datetime.datetime.now():%Y%m%d_%H%M%S}")
    shutil.copy2(TARGET, bak)
    TARGET.write_text(new_src)
    print(f"[+] Patched {TARGET}")
    print(f"[+] Backup at {bak}")
    print()
    print("Next steps:")
    print("  1. systemctl --user restart eeg-reporter.service")
    print("  2. For each failed stem: rm /home/leige/eeg-reporter/reports/<STEM>.processed")
    print("     Then wait for watcher to pick them up")
    print("  Or for single retry:")
    print("     python3 /home/leige/eeg-reporter/process_one.py <STEM> --redo")


if __name__ == "__main__":
    main()
