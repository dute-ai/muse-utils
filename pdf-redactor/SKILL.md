---
name: "pdf_redactor"
description: "Redact sensitive values from PDFs entirely locally: deterministic detectors (SSN/ITIN, Luhn-checked cards, ABA-checked routing numbers, phones, emails, account numbers) plus an optional local-LLM pass (Ollama, or an OpenAI-compatible server like mlx_lm.server) for names and addresses. True text removal via PyMuPDF, metadata scrub, and a verify pass that fails loudly if anything survives. Nothing leaves the machine."
---

# pdf-redactor

## Purpose
Make a PDF safe to share — e.g. send excerpts of a tax return to an AI or
an advisor — without any of its text ever leaving the local machine. Cloud
redaction products (Foxit Smart Redact, Redactable, ...) send document
text to someone else's cloud; for the document you're trying to protect,
that's the leak itself. This tool is the local alternative.

## Tooling
Two scripts live next to this file (installed at
`~/workspace/skills/pdf-redactor/`):

- `redact.py` — the redactor. Pipeline:
  1. Extract text with PyMuPDF.
  2. Detect: pattern recognizers (SSN/ITIN with SSA rules, credit cards
     with Luhn, routing numbers with the ABA checksum — a random 9-digit
     number is *not* flagged — phones, emails, account numbers next to
     keywords), then an optional local-LLM pass for what patterns can't
     know (names, addresses, odd formats). Every string the model returns
     is verified to literally appear in the page text before use
     (anti-hallucination), and a model failure never blocks the run.
  3. Redact via PyMuPDF redaction annotations + `apply_redactions()` —
     the text is *removed*, not painted over with a black box.
  4. Scrub document metadata.
  5. Verify: re-open the output, re-run every detector; exit non-zero if
     anything survived. The report lists counts by type only, never the
     values themselves.
- `make_sample.py` — generates a fake 1040-like PDF with planted PII
  (plus a checksum-failing decoy number) for safe end-to-end testing.

Backends for the LLM pass:
- `--backend ollama` (default) — Ollama `/api/chat` on :11434.
- `--backend openai` — any OpenAI-compatible server on :8080, e.g.
  `mlx_lm.server` (the fast path on Apple Silicon) or LM Studio.

## One-time setup
```sh
python3 -m venv .venv && .venv/bin/pip install pymupdf
# optional LLM pass, one of:
ollama serve                                # + ollama pull qwen3:30b-a3b
mlx_lm.server --model mlx-community/Qwen3-30B-A3B-4bit --port 8080
```

## Run
```sh
.venv/bin/python redact.py input.pdf -o output.pdf
.venv/bin/python redact.py input.pdf -o output.pdf --llm-model qwen3:30b-a3b
.venv/bin/python redact.py input.pdf -o output.pdf --backend openai \
    --llm-model mlx-community/Qwen3-30B-A3B-4bit
```

## Operating Rules
1. **Local means local.** Never upload the unredacted document anywhere,
   and never paste its raw text into a chat. The redacted output plus the
   counts-only report are the only things that leave the machine.
2. **Check the exit code.** A non-zero exit means the verify pass found a
   survivor — do not share that output. Read the report's
   `remaining_after_redaction` before trusting any run.
3. **The LLM pass is a net, not a guarantee.** Patterns catch the
   structured numbers deterministically; names/addresses rely on the
   model. For high-stakes documents, eyeball the redacted output text
   before sharing.
4. Reasoning models (Qwen3 etc.) need token headroom: `redact.py` asks
   the OpenAI-compatible backend for 4096 max tokens, because a reasoning
   model can burn a small budget mid-thought and return no answer at all.
5. Not in v1: scanned/image PDFs (no OCR yet — native-text PDFs like
   TurboTax output are covered).
