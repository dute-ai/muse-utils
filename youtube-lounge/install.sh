#!/bin/bash
# install.sh — install the youtube-lounge skill.
#
# Standalone: this directory is self-contained. Download just youtube-lounge/
# (no need for the full muse-utils repo) and run this script.
set -euo pipefail
UTIL_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="youtube-lounge"
DEST="$HOME/workspace/skills/$NAME"

rm -rf "$DEST"
mkdir -p "$DEST"
# explicit skill payload — README.md and install.sh stay out
cp "$UTIL_DIR/SKILL.md" "$DEST/"
cp "$UTIL_DIR/yt-tv" "$DEST/"
chmod +x "$DEST/yt-tv"

echo "Installed skill -> $DEST"
echo
echo "Pair each TV once with the code from its YouTube app"
echo "(Settings -> Link with TV code):"
echo "  $DEST/yt-tv --tv \"My TV\" pair <code>"
