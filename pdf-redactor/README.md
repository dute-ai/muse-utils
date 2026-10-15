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
     9-digit number is *not* flagged), phones, emails, EINs, dates of
     birth next to their labels, and account numbers appearing next to
     keywords — plus two shape-based catchers: names sitting right of
     the labels tax forms actually use ("Name(s) shown on return:",
     "Your first name and last name:", ...), address lines (street +
     city/state/ZIP), and bare 10–15 digit runs no checksum claimed.
     Form-field values are scanned
     too: a fillable form (e.g. the IRS 1040) stores typed values in a
     layer apart from the page text, including bare-digit comb fields.
     Whatever is found on any page then *propagates*: the same value
     is hunted on every other page, because returns repeat the
     taxpayer's name in headers and schedules the label pass may only
     catch once;
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
5. **Verify** — the output is re-opened and checked two ways: every
   detector re-runs, *and* every literal value that was redacted is
   confirmed absent (the pattern scan alone shares the detectors'
   blind spots — it cannot see an LLM-found name survive). If
   anything survives, the tool exits non-zero and says so.
   A PDF with no extractable text on any page is refused outright
   (exit 2): it is a scan, and "0 found, OK" would be a lie.

The report lists counts by type only — never the values themselves.

## Setup
```sh
python3 -m venv .venv && .venv/bin/pip install pymupdf
```

For the LLM pass, run one local server:

- **Ollama** (any platform): `ollama serve`, pull a model such as
  `qwen3:30b-a3b`.
- **MLX** (Apple Silicon, fastest): `.venv/bin/pip install mlx-lm`,
  then `.venv/bin/mlx_lm.server --model mlx-community/Qwen3-30B-A3B-4bit
  --port 8080` (the binary lives in the venv — a bare `mlx_lm.server`
  is "command not found"; or skip this entirely and let
  `./redact.sh input.pdf --llm` start it for you).
  On a 64 GB Mac, a 30B-class 4-bit model (~20 GB) is the sweet spot;
  an 8B 4-bit (~5 GB) works fine and is quicker to download.

## Run — the easy way
`redact.sh` is the one-command front door. It creates the venv on
first run, starts the model server for you when you ask for a model
pass, and defaults the output name:
```sh
./redact.sh input.pdf              # patterns only — seconds
./redact.sh input.pdf --llm        # + local LLM pass
./redact.sh input.pdf --vision     # + vision pass on rendered pages
./redact.sh input.pdf --llm -o clean.pdf
```
Output lands next to the input as `<input>_redacted.pdf`, with the
JSON report beside it. The model server, once started, is left
running for the next run (`pkill -f mlx_lm.server` stops it).

## Run — by hand
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

Speed, learned the hard way: reasoning models (Qwen3 family) think
before they answer, and that thinking is nearly all of the wait on a
long return. A scanner should answer, not deliberate — `redact.py`
now asks the server to disable thinking (`enable_thinking: false` /
Ollama `think: false`), falling back to a 4096-token budget if the
server rejects the flag (some servers also default to 512 output
tokens, which a reasoning model can spend mid-thought and return an
empty answer — the fallback keeps that from silently skipping the
page). Identical pages are only sent to the model once, and progress
is printed per page so a long run doesn't look hung. Empty or
malformed model replies count as "no hits" rather than crashing.

## Test
```sh
tests/run.sh
```
Detector unit tests run anywhere (PyMuPDF is stubbed; the detectors are
stdlib-only). The end-to-end sample run — a fake return with planted
PII, 0 remaining, decoy number and income figures untouched — runs
when PyMuPDF is importable, and skips with a note otherwise.
Further end-to-end runs cover the form-field blind spot (values
stored in AcroForm fields, cleared at the source and verified gone),
cross-page propagation (a name labelled on page 1 removed from an
unlabelled page 2), and the image-only guard (a blank PDF must fail
with exit 2, never "OK").

By hand:
```sh
.venv/bin/python make_sample.py   # fake return with planted PII
.venv/bin/python redact.py sample_return.pdf -o sample_redacted.pdf
```

## Not in v1
- Scanned/image-only PDFs (needs OCR — planned: ocrmypdf or a vision
  model with region output). A pure scan is now *refused* (exit 2)
  instead of silently passing: the vision pass helps on born-digital
  pages, but on a scan its candidates cannot be corroborated or
  located in a text layer that doesn't exist.
- Names that never sit next to a known label, without the LLM or
  vision pass (the label pass covers the standard tax-form fields;
  the model passes cover the rest).
- A GUI. It's a CLI with a one-command launcher, because it was built
  in an evening.

## Files
- `redact.sh` — one-command launcher (venv, model server, defaults).
- `redact.py` — the redactor (patterns + optional LLM/vision passes + verify).
- `make_sample.py` — fake-return generator with planted PII for testing.
- `tests/` — detector unit tests, a mock OpenAI-compatible server, and
  the end-to-end sample check.
