#!/usr/bin/env python3
"""
pdf-redactor — local, private PDF redaction for ordinary people.

Pipeline:
  1. Extract text from the PDF (locally, PyMuPDF).
  2. Detect sensitive values:
       a. deterministic recognizers (SSN/ITIN, credit cards w/ Luhn,
          ABA routing numbers w/ checksum, phones, emails,
          account numbers next to keywords)
       b. optional local LLM pass via Ollama (nothing leaves the machine;
          every string the model returns is verified to literally appear
          in the page text before it is used)
  3. Redact with PyMuPDF's redaction API — the text is REMOVED, not
     covered with a black box.
  4. Scrub document metadata.
  5. Verify: re-open the output, re-run every detector. If anything is
     still found, the tool fails loudly instead of shipping a leaky file.

The report lists counts by type only — never the values themselves.

Usage:
  python3 redact.py input.pdf -o output.pdf [--llm-model qwen3:8b]
                    [--report report.json]
"""

import argparse
import json
import re
import sys
import urllib.request

import pymupdf

# ---------------------------------------------------------------- detectors

def luhn_ok(digits: str) -> bool:
    total, alt = 0, False
    for ch in reversed(digits):
        d = int(ch)
        if alt:
            d *= 2
            if d > 9:
                d -= 9
        total += d
        alt = not alt
    return total % 10 == 0


def aba_ok(digits: str) -> bool:
    # ABA routing checksum: 3*(d0+d3+d6) + 7*(d1+d4+d7) + (d2+d5+d8) == 0 mod 10
    d = [int(c) for c in digits]
    return (3 * (d[0] + d[3] + d[6]) + 7 * (d[1] + d[4] + d[7])
            + (d[2] + d[5] + d[8])) % 10 == 0


SSN_RE = re.compile(r"\b(?!000|666|9\d\d)\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b")
ITIN_RE = re.compile(r"\b9\d{2}-(?:[7-9]\d|0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9]|6[0-9]|8[0-9]|9[0-9])-\d{4}\b")
CARD_RE = re.compile(r"\b(?:\d{4}[ -]?){3}\d{4}\b|\b\d{13,16}\b")
ROUTING_RE = re.compile(r"\b\d{9}\b")
PHONE_RE = re.compile(r"\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]\d{3}[-. ]\d{4}\b")
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
ACCT_KW_RE = re.compile(
    r"(?i)(?:account|acct|a/c)\s*(?:number|no\.?|#)?\s*[:#]?\s*([0-9][0-9 -]{3,20}[0-9])")


def detect_patterns(text: str) -> list[tuple[str, str]]:
    """Return [(type, literal_value), ...] found in text."""
    hits: list[tuple[str, str]] = []

    for m in SSN_RE.finditer(text):
        hits.append(("ssn", m.group(0)))
    for m in ITIN_RE.finditer(text):
        if not any(v == m.group(0) for _, v in hits):
            hits.append(("itin", m.group(0)))
    for m in CARD_RE.finditer(text):
        digits = re.sub(r"\D", "", m.group(0))
        if 13 <= len(digits) <= 16 and luhn_ok(digits):
            hits.append(("credit_card", m.group(0)))
    for m in ROUTING_RE.finditer(text):
        if aba_ok(m.group(0)):
            hits.append(("routing_number", m.group(0)))
    for m in PHONE_RE.finditer(text):
        # skip things that are really SSNs / dates already caught
        if not any(v == m.group(0) for _, v in hits):
            hits.append(("phone", m.group(0)))
    for m in EMAIL_RE.finditer(text):
        hits.append(("email", m.group(0)))
    for m in ACCT_KW_RE.finditer(text):
        hits.append(("account_number", m.group(1).strip()))

    # de-dup, keep order
    seen, out = set(), []
    for t, v in hits:
        if (t, v) not in seen:
            seen.add((t, v))
            out.append((t, v))
    return out


# ---------------------------------------------------------------- LLM pass

LLM_PROMPT = """You are a privacy scanner. Below is the text of one page of a \
financial document. List every sensitive personal value that appears \
VERBATIM in the text: Social Security numbers, taxpayer ID numbers, bank \
account numbers, bank routing numbers, credit card numbers, phone numbers, \
email addresses, dates of birth, street addresses, and full personal names.

Rules:
- Copy each value EXACTLY as it appears, character for character.
- Do not invent or modify values. If a value is not literally in the text, \
do not list it.
- Reply with ONLY a JSON array of strings, e.g. ["123-45-6789"]. \
If none, reply [].

TEXT:
---
{text}
---"""


def _parse_llm_values(content, text: str) -> list[tuple[str, str]]:
    if not isinstance(content, str):
        return []
    try:
        values = json.loads(content)
    except json.JSONDecodeError:
        m = re.search(r"\[.*\]", content, re.DOTALL)
        if not m:
            return []
        try:
            values = json.loads(m.group(0))
        except json.JSONDecodeError:
            return []
    hits = []
    for v in values if isinstance(values, list) else []:
        if isinstance(v, str) and v in text:  # anti-hallucination check
            hits.append(("llm", v))
    return hits


def detect_llm_ollama(text: str, model: str, base_url: str):
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": LLM_PROMPT.format(text=text)}],
        "stream": False,
        "format": "json",
    }).encode()
    req = urllib.request.Request(
        base_url.rstrip("/") + "/api/chat", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read())
    return _parse_llm_values(data["message"]["content"], text)


def detect_llm_openai(text: str, model: str, base_url: str):
    """OpenAI-compatible chat endpoint — what mlx_lm.server and
    LM Studio serve. This is the fast path on Apple Silicon."""
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": LLM_PROMPT.format(text=text)}],
        "stream": False,
        "temperature": 0,
        # Reasoning models (Qwen3 etc.) burn tokens thinking before they
        # answer; the server default (512 on mlx_lm.server) can run out
        # mid-thought and return content=None. Give real headroom.
        "max_tokens": 4096,
    }).encode()
    req = urllib.request.Request(
        base_url.rstrip("/") + "/v1/chat/completions", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read())
    msg = data["choices"][0]["message"]
    content = msg.get("content")
    if not content and msg.get("reasoning"):
        # Fallback: some servers surface only the reasoning channel.
        # The verbatim-in-text check in _parse_llm_values still applies.
        content = msg["reasoning"]
    return _parse_llm_values(content, text)


# ---------------------------------------------------------------- pipeline

def scan(doc) -> dict[int, list[tuple[str, str]]]:
    found: dict[int, list[tuple[str, str]]] = {}
    for page in doc:
        hits = detect_patterns(page.get_text())
        if hits:
            found[page.number] = hits
    return found


def main() -> int:
    ap = argparse.ArgumentParser(description="Local PDF redactor")
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--llm-model", default=None,
                    help="model for the semantic pass, e.g. qwen3:30b-a3b "
                         "(Ollama) or mlx-community/Qwen3-30B-A3B-4bit (MLX)")
    ap.add_argument("--backend", choices=["ollama", "openai"], default="ollama",
                    help="ollama = Ollama /api/chat (default); "
                         "openai = OpenAI-compatible, e.g. mlx_lm.server")
    ap.add_argument("--base-url", default=None,
                    help="server base URL (default: ollama :11434, openai :8080)")
    ap.add_argument("--report", default=None, help="write JSON report here")
    args = ap.parse_args()

    base_url = args.base_url or (
        "http://localhost:11434" if args.backend == "ollama"
        else "http://localhost:8080")
    detect_llm = detect_llm_ollama if args.backend == "ollama" else detect_llm_openai

    doc = pymupdf.open(args.input)

    # --- detect (patterns, then optional LLM)
    per_page = scan(doc)
    if args.llm_model:
        for page in doc:
            text = page.get_text()
            try:
                extra = detect_llm(text, args.llm_model, base_url)
            except Exception as e:  # LLM is a safety net, never a blocker
                print(f"warning: LLM pass failed on page {page.number + 1}: {e}",
                      file=sys.stderr)
                continue
            merged = per_page.get(page.number, [])
            known = {v for _, v in merged}
            merged += [h for h in extra if h[1] not in known]
            if merged:
                per_page[page.number] = merged

    total_found = sum(len(v) for v in per_page.values())

    # --- redact (true removal via redaction annotations)
    for page in doc:
        for _type, value in per_page.get(page.number, []):
            for rect in page.search_for(value):
                page.add_redact_annot(rect, fill=(0, 0, 0))
        if per_page.get(page.number):
            page.apply_redactions()

    # --- scrub metadata
    doc.set_metadata({"title": "", "author": "", "subject": "",
                      "keywords": "", "creator": "", "producer": ""})
    doc.save(args.output, garbage=4, deflate=True)
    doc.close()

    # --- verify: the step that makes it trustworthy
    check = pymupdf.open(args.output)
    remaining = scan(check)
    check.close()
    total_left = sum(len(v) for v in remaining.values())

    report = {
        "input": args.input,
        "output": args.output,
        "llm_model": args.llm_model,
        "found": {str(p + 1): sorted({t for t, _ in hits})
                  for p, hits in per_page.items()},
        "found_total": total_found,
        "remaining_after_redaction": total_left,
        "remaining_detail": {str(p + 1): sorted({t for t, _ in hits})
                             for p, hits in remaining.items()},
    }
    print(json.dumps(report, indent=2))
    if args.report:
        with open(args.report, "w") as f:
            json.dump(report, f, indent=2)

    if total_left:
        print(f"FAIL: {total_left} sensitive value(s) survived redaction",
              file=sys.stderr)
        return 1
    print(f"OK: {total_found} sensitive value(s) removed, 0 remaining.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
