#!/usr/bin/env python3
"""
Diagnostic for EEG Reporter Ollama parse failures.
Replays the report_generator prompt for a specific stem and dumps the raw model output.

Usage: python3 diagnose_ollama_parse.py FA00133V
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, "/home/leige/eeg-reporter")
import requests

from config import OLLAMA_HOST, OLLAMA_MODEL, OLLAMA_TIMEOUT, REPORTS_DIR  # type: ignore
from report_generator import _build_prompt, SYSTEM_PROMPT  # type: ignore


def latest_report(stem: str) -> Path:
    matches = sorted(Path(REPORTS_DIR).glob(f"{stem}_*.json"))
    if not matches:
        sys.exit(f"No reports found for stem {stem}")
    return matches[-1]


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: python3 diagnose_ollama_parse.py <STEM>")
    stem = sys.argv[1]
    rpt_path = latest_report(stem)
    print(f"[*] Loading findings from {rpt_path}")
    with rpt_path.open() as f:
        data = json.load(f)
    findings = data.get("findings", {})
    if not findings:
        sys.exit("No 'findings' block in saved report")

    prompt = _build_prompt(findings)
    print(f"[*] Prompt built ({len(prompt)} chars)")
    print(f"[*] Sending to {OLLAMA_HOST} / model={OLLAMA_MODEL}")
    print("=" * 60)

    resp = requests.post(
        f"{OLLAMA_HOST}/api/generate",
        json={
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "stream": False,
            "system": SYSTEM_PROMPT,
            "options": {"temperature": 0.2, "num_predict": 1024},
        },
        timeout=OLLAMA_TIMEOUT,
    )
    resp.raise_for_status()
    raw_text = resp.json().get("response", "")
    print(f"RAW RESPONSE LENGTH: {len(raw_text)} chars")
    print(f"RAW RESPONSE:")
    print("-" * 60)
    print(raw_text)
    print("-" * 60)

    # Now try the parse path
    cleaned = re.sub(r"```(?:json)?", "", raw_text).strip()
    m = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if not m:
        print("\n[!] NO JSON OBJECT FOUND IN RESPONSE")
        return
    print(f"\n[+] JSON regex matched {len(m.group())} chars")
    try:
        parsed = json.loads(m.group())
        print("[+] json.loads SUCCEEDED")
        print(f"    keys: {list(parsed.keys())}")
    except json.JSONDecodeError as e:
        print(f"[!] json.loads FAILED: {e}")
        print(f"[!] Error at char {e.pos}: ...{m.group()[max(0,e.pos-50):e.pos+50]!r}...")

    # Save raw response for further analysis
    out = Path(f"/tmp/ollama_raw_{stem}.txt")
    out.write_text(raw_text)
    print(f"\n[*] Raw response saved to {out}")


if __name__ == "__main__":
    main()
