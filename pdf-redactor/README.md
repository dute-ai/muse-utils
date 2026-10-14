# pdf-redactor

Local, private PDF redaction. Nothing leaves your machine.

## Why
Every "smart" redaction product (Foxit Smart Redact, Redactable, ...)
sends your document text to a cloud AI. For a tax return, that's the
very leak you're trying to prevent. This tool runs entirely locally:
deterministic pattern detectors, an optional pass by a local LLM, true
text removal, and a verify step that fails loudly if anything survives.

Built for a real case: checking how a prior-year tax return handled a
specific schedule, with an AI's help, without the return ever leaving
the owner's machines.

## How it works
1. **Extract** — PyMuPDF pulls the text.
2. **Detect** — three layers:
   - deterministic recognizers: SSN/ITIN (SSA rules — dashed, spaced,
     and one-digit-per-box layouts), credit cards
     (Luhn check), bank routing numbers (ABA checksum — a random
     9-digit number is *not* flagged), phones, emails, and account
     numbers appearing next to keywords. Form-field values are scanned
     too: a fillable form (e.g. the IRS 1040) stores typed values in a
     layer apart from the page text, including bare-digit comb fields;
   - optional local LLM pass: the model flags anything the patterns
     miss (names, addresses, odd formats). Every string it returns is
     verified to literally appear in the text before use
     (anti-hallucination), and a model failure never blocks the run;
   - optional vision pass (`--vision-model`): a vision model reads the
     *rendered page image*, the way a human would. Its candidates are
     only used when corroborated by the document's own data (page text
     + field values, separators ignored) — uncorroborated candidates
     are counted in the report and ignored, never printed.
3. **Redact** — PyMuPDF redaction annotations + `apply_redactions()`:
   the text is *removed*, not painted over. Values stored in form
   fields are cleared in the field itself — text redaction alone
   strips their rendered appearance but the value survives and
   re-renders.
4. **Scrub** — document metadata is blanked.
5. **Verify** — the output is re-opened and every detector re-run.
   If anything survives, the tool exits non-zero and says so.

The report lists counts by type only — never the values themselves.

## Setup
```sh
python3 -m venv .venv && .venv/bin/pip install pymupdf
```

For the LLM pass, run one local server:

- **Ollama** (any platform): `ollama serve`, pull a model such as
  `qwen3:30b-a3b`.
- **MLX** (Apple Silicon, fastest): `pip install mlx-lm`, then
  `mlx_lm.server --model mlx-community/Qwen3-30B-A3B-4bit --port 8080`.
  On a 64 GB Mac, a 30B-class 4-bit model (~20 GB) is the sweet spot;
  an 8B 4-bit (~5 GB) works fine and is quicker to download.

## Run
```sh
.venv/bin/python redact.py input.pdf -o output.pdf
# LLM pass via Ollama:
.venv/bin/python redact.py input.pdf -o output.pdf --llm-model qwen3:30b-a3b
# LLM pass via MLX — start the server first (see Setup):
.venv/bin/python redact.py input.pdf -o output.pdf --backend openai \
    --llm-model mlx-community/Qwen3-30B-A3B-4bit
# Vision pass — the model reads the rendered page, not just the text.
# Needs a vision-capable server (Ollama vision model, or mlx_vlm.server;
# plain mlx_lm.server is text-only):
.venv/bin/python redact.py input.pdf -o output.pdf --backend openai \
    --vision-model mlx-community/Qwen3-VL-8B-Instruct-4bit
```

One gotcha, learned the hard way: reasoning models (Qwen3 family) think
before they answer, and some servers default to 512 output tokens — the
model can spend the whole budget mid-thought and return an empty answer,
silently skipping the page. `redact.py` requests 4096 tokens from
OpenAI-compatible backends, and treats an empty or malformed model reply
as "no hits" rather than crashing.

## Test
```sh
tests/run.sh
```
Detector unit tests run anywhere (PyMuPDF is stubbed; the detectors are
stdlib-only). The end-to-end sample run — a fake return with planted
PII, verified 8 pattern hits + the LLM catching the taxpayer name on
both pages, 0 remaining, decoy number and income figures untouched —
runs when PyMuPDF is importable, and skips with a note otherwise.
A second end-to-end run covers the form-field blind spot: values
stored in AcroForm fields (a dashed SSN field and a bare-digit comb
field) must be found, cleared at the source, and verified gone.

By hand:
```sh
.venv/bin/python make_sample.py   # fake return with planted PII
.venv/bin/python redact.py sample_return.pdf -o sample_redacted.pdf
```

## Not in v1
- Scanned/image PDFs (needs OCR — planned: ocrmypdf or vision model).
  The vision pass helps on born-digital pages; on a pure scan its
  candidates cannot be corroborated or located, so they are reported
  as unverified rather than removed.
- Names/addresses without the LLM or vision pass (patterns can't know
  what a name is; the model passes cover them).
- A GUI. It's a CLI, because it was built in an evening.

## Files
- `redact.py` — the redactor (patterns + optional LLM/vision passes + verify).
- `make_sample.py` — fake-return generator with planted PII for testing.
- `tests/` — detector unit tests, a mock OpenAI-compatible server, and
  the end-to-end sample check.
