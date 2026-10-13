#!/bin/bash
# install.sh — install the pdf-redactor skill.
#
# Standalone: this directory is self-contained. Download just pdf-redactor/
# (no need for the full muse-utils repo) and run this script.
set -euo pipefail
UTIL_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="pdf-redactor"
DEST="$HOME/workspace/skills/$NAME"

rm -rf "$DEST"
mkdir -p "$DEST"
# explicit skill payload — README.md, install.sh and tests/ stay out
cp "$UTIL_DIR/SKILL.md" "$DEST/"
cp "$UTIL_DIR/redact.py" "$UTIL_DIR/make_sample.py" "$DEST/"

echo "Installed skill -> $DEST"
echo
echo "One-time setup next to the installed scripts:"
echo "  cd $DEST"
echo "  python3 -m venv .venv && .venv/bin/pip install pymupdf"
echo "Optional LLM pass: run Ollama, or an OpenAI-compatible server"
echo "(e.g. mlx_lm.server on Apple Silicon) — see README.md."
