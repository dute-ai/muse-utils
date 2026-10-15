---
name: "pdf_redactor"
description: "Redact sensitive values from PDFs entirely locally: deterministic detectors (SSN/ITIN, Luhn-checked cards, ABA-checked routing numbers, phones, emails, EINs, label-anchored names and addresses, account numbers — form-field values included, with cross-page propagation) plus optional local-LLM and vision passes (Ollama, or an OpenAI-compatible server like mlx_lm.server / mlx_vlm.server). One-command launcher (redact.sh) handles the venv and model server. True text removal via PyMuPDF, metadata scrub, and a verify pass that fails loudly if anything survives; image-only PDFs are refused. Nothing leaves the machine."
---

# pdf-redactor

## Purpose
Make a PDF safe to share — e.g. send excerpts of a tax return to an AI or
an advisor — without any of its text ever leaving the local machine. Cloud
redaction products (Foxit Smart Redact, Redactable, ...) send document
text to someone else's cloud; for the document you're trying to protect,
that's the leak itself. This tool is the local alternative.

## Tooling
The scripts live next to this file (installed at
`~/workspace/skills/pdf-redactor/`):

- `redact.sh` — the one-command front door for a human at a terminal:
  `./redact.sh input.pdf [--llm|--vision] [-o out.pdf]`. Creates the
  venv on first run, starts the MLX/Ollama model server when a model
  pass is requested, defaults the output to `<input>_redacted.pdf`
  plus a `.report.json` beside it. Prefer it over hand-rolling
  `redact.py` invocations for the user.
- `redact.py` — the redactor. Pipeline:
  1. Extract page text *and* form-field values with PyMuPDF — a
     fillable form (e.g. the IRS 1040) stores typed values in AcroForm
     fields, apart from the page text.
  2. Detect: pattern recognizers (SSN/ITIN with SSA rules — dashed,
     spaced, and one-digit-per-box layouts; bare-digit values inside
     form fields classified by checksum/assignment rules; credit cards
     with Luhn, routing numbers with the ABA checksum — a random 9-digit
     number is *not* flagged — phones, emails, EINs, dates of birth
     next to their labels, account numbers next to keywords), plus
     label-anchored names (values right of "Name(s) shown on return:"
     and kin), address lines (street, city/state/ZIP), and bare
     10–15-digit runs. Found values propagate to every page before
     redaction. Then an optional local-LLM pass for what patterns
     still can't know (unlabelled names, odd formats), and an optional
     vision pass whose candidates count only when corroborated by the
     document's own data. Every string a model returns is verified
     against the document before use (anti-hallucination), and a model
     failure never blocks the run. A PDF with no extractable text on
     any page is refused (exit 2) rather than blessed.
  3. Redact via PyMuPDF redaction annotations + `apply_redactions()` —
     the text is *removed*, not painted over with a black box. Values
     found inside form fields are cleared in the field itself; text
     redaction alone strips their appearance while the value survives.
  4. Scrub document metadata.
  5. Verify: re-open the output, re-run every detector, *and* confirm
     every literal redacted value is absent; exit non-zero if anything
     survived. The report lists counts by type only, never the values
     themselves.
- `make_sample.py` — generates a fake 1040-like PDF with planted PII
  (plus a checksum-failing decoy number) for safe end-to-end testing.

Backends for the model passes:
- `--backend ollama` (default) — Ollama `/api/chat` on :11434.
- `--backend openai` — any OpenAI-compatible server on :8080, e.g.
  `mlx_lm.server` (the fast path on Apple Silicon) or LM Studio.
- `--vision-model` — a vision model reads each rendered page image
  (Ollama vision models, or an OpenAI-compatible vision server such
  as `mlx_vlm.server`; plain `mlx_lm.server` is text-only).

## One-time setup
None for the launcher path — `redact.sh` builds its own venv. By hand:
```sh
python3 -m venv .venv && .venv/bin/pip install pymupdf
# optional LLM pass, one of:
ollama serve                                # + ollama pull qwen3:30b-a3b
.venv/bin/mlx_lm.server --model mlx-community/Qwen3-30B-A3B-4bit --port 8080
```

## Run
```sh
./redact.sh input.pdf              # patterns only
./redact.sh input.pdf --llm        # + LLM pass (server auto-started)
./redact.sh input.pdf --vision     # + vision pass
# by hand:
.venv/bin/python redact.py input.pdf -o output.pdf
.venv/bin/python redact.py input.pdf -o output.pdf --llm-model qwen3:30b-a3b
.venv/bin/python redact.py input.pdf -o output.pdf --backend openai \
    --llm-model mlx-community/Qwen3-30B-A3B-4bit
.venv/bin/python redact.py input.pdf -o output.pdf --backend openai \
    --vision-model mlx-community/Qwen3-VL-8B-Instruct-4bit
```

## Operating Rules
1. **Local means local.** Never upload the unredacted document anywhere,
   and never paste its raw text into a chat. The redacted output plus the
   counts-only report are the only things that leave the machine.
2. **Check the exit code.** A non-zero exit means the verify pass found a
   survivor — do not share that output. Read the report's
   `remaining_after_redaction` before trusting any run.
3. **The LLM pass is a net, not a guarantee.** Patterns catch the
   structured numbers, labelled names, and addresses deterministically;
   the model covers the unlabelled remainder. For high-stakes
   documents, eyeball the redacted output text before sharing.
4. Reasoning models (Qwen3 etc.): `redact.py` asks the server to
   disable thinking (the wait is nearly all deliberation), and only
   falls back to a 4096-token thinking budget if the server rejects
   the flag — a reasoning model can burn a small budget mid-thought
   and return no answer at all.
5. Exit 2 means image-only: no text layer to check or redact (pure
   scan). OCR is not in v1 — do not work around the refusal by
   trusting the vision pass on a scan; its candidates there are
   uncorroborated by design. Native-text PDFs (TurboTax output,
   fillable IRS forms) are covered.
