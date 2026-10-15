#!/bin/bash
# redact.sh — the one-command front door for pdf-redactor.
#
#   ./redact.sh tax-return.pdf              patterns only, seconds
#   ./redact.sh tax-return.pdf --llm        + local LLM pass (names etc.)
#   ./redact.sh tax-return.pdf --vision     + vision pass on rendered pages
#   ./redact.sh tax-return.pdf --llm -o clean.pdf
#
# Output defaults to <input>_redacted.pdf, with the JSON report written
# next to it as <input>_redacted.report.json and printed to the terminal.
# Any other redact.py options pass through (e.g. --llm-model, --backend).
#
# First run creates .venv/ and installs PyMuPDF. With --llm, if no model
# server is up yet, this starts one from .venv (mlx-lm on Apple Silicon)
# and waits for it — the first start also downloads the model (~5 GB for
# the default 8B), which can take a while. The server is left running;
# stop it with:  pkill -f mlx_lm.server
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
PY="$DIR/.venv/bin/python"

usage() { sed -n '2,20p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

if [ ! -x "$PY" ]; then
    echo "first run: creating .venv and installing pymupdf..." >&2
    python3 -m venv .venv
    .venv/bin/pip install -q pymupdf
fi

INPUT=""; OUT=""; WANT_LLM=0; WANT_VISION=0; EXTRA=()
for a in "$@"; do
    case "$a" in
        --llm) WANT_LLM=1 ;;
        --vision) WANT_VISION=1 ;;
        -o|--output) OUT="__NEXT__" ;;
        -h|--help) usage; exit 0 ;;
        *)
            if [ "$OUT" = "__NEXT__" ]; then OUT="$a";
            elif [ -z "$INPUT" ] && [ -f "$a" ]; then INPUT="$a";
            else EXTRA+=("$a"); fi ;;
    esac
done
if [ -z "$INPUT" ]; then usage >&2; exit 2; fi
[ "$OUT" = "__NEXT__" ] && OUT=""
[ -z "$OUT" ] && OUT="${INPUT%.pdf}_redacted.pdf"
REPORT="${OUT%.pdf}.report.json"

CMD=("$PY" redact.py "$INPUT" -o "$OUT" --report "$REPORT")

server_up() { curl -s -m 2 "http://localhost:$1/v1/models" >/dev/null 2>&1; }
ollama_up() { curl -s -m 2 "http://localhost:11434/api/tags" >/dev/null 2>&1; }

if [ "$WANT_LLM" = 1 ] || [ "$WANT_VISION" = 1 ]; then
    if server_up 8080; then
        BACKEND=openai
    elif ollama_up; then
        BACKEND=ollama
    elif [ "$WANT_VISION" = 1 ] && "$PY" -c "import mlx_vlm" 2>/dev/null; then
        VMODEL="${PDF_REDACTOR_VISION_MODEL:-mlx-community/Qwen3-VL-8B-Instruct-4bit}"
        echo "starting vision server ($VMODEL) — first start downloads it..." >&2
        nohup "$PY" -m mlx_vlm.server --model "$VMODEL" --port 8080 \
            > vision-server.log 2>&1 &
        BACKEND=openai
    elif [ -x "$DIR/.venv/bin/mlx_lm.server" ]; then
        MODEL="${PDF_REDACTOR_LLM_MODEL:-mlx-community/Qwen3-8B-4bit}"
        echo "starting MLX server ($MODEL) — first start downloads it..." >&2
        nohup "$DIR/.venv/bin/mlx_lm.server" --model "$MODEL" --port 8080 \
            > mlx-server.log 2>&1 &
        BACKEND=openai
    else
        echo "no local model server found. On a Mac:" >&2
        echo "  .venv/bin/pip install mlx-lm     # text LLM pass" >&2
        echo "  .venv/bin/pip install mlx-vlm    # + vision pass" >&2
        echo "then re-run. (Or start Ollama and re-run.)" >&2
        exit 3
    fi
    if [ "$BACKEND" = openai ] && ! server_up 8080; then
        printf "waiting for the model server" >&2
        for _ in $(seq 1 450); do
            server_up 8080 && break
            printf "." >&2; sleep 2
        done
        echo >&2
        server_up 8080 || { echo "server did not come up; see *.log here" >&2; exit 3; }
    fi
    CMD+=(--backend "$BACKEND")
    if [ "$WANT_LLM" = 1 ]; then
        if [ "$BACKEND" = openai ]; then
            CMD+=(--llm-model "${PDF_REDACTOR_LLM_MODEL:-mlx-community/Qwen3-8B-4bit}")
        else
            CMD+=(--llm-model "${PDF_REDACTOR_LLM_MODEL:-qwen3:30b-a3b}")
        fi
    fi
    if [ "$WANT_VISION" = 1 ]; then
        if [ "$BACKEND" = openai ]; then
            CMD+=(--vision-model "${PDF_REDACTOR_VISION_MODEL:-mlx-community/Qwen3-VL-8B-Instruct-4bit}")
        else
            CMD+=(--vision-model "${PDF_REDACTOR_VISION_MODEL:-qwen3-vl}")
        fi
    fi
fi

exec "${CMD[@]}" ${EXTRA[@]+"${EXTRA[@]}"}
