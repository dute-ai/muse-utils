#!/bin/bash
# install.sh — install the mac-remote skill.
#
# Standalone: this directory is self-contained. Download just mac-remote/
# (no need for the full muse-utils repo) and run this script.
set -euo pipefail
UTIL_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="mac-remote"
DEST="$HOME/workspace/skills/$NAME"

rm -rf "$DEST"
mkdir -p "$DEST"
# explicit skill payload — README.md and install.sh stay out
cp "$UTIL_DIR/SKILL.md" "$DEST/"
cp -R "$UTIL_DIR/bin" "$UTIL_DIR/references" "$DEST/"
chmod +x "$DEST/bin/"*

# state dir lives next to the utility; record it for the installed skill
STATE_DIR="$UTIL_DIR/state"
mkdir -p "$STATE_DIR"
[ -f "$STATE_DIR/config" ] || printf '# MAC_REMOTE_USER=\n# MAC_REMOTE_HOST=\n# MAC_SSH_KEY=\n# MAC_REMOTE_TMUX=\n' > "$STATE_DIR/config"
echo "$STATE_DIR" > "$DEST/.state-dir"

echo "Installed skill -> $DEST"
echo "State dir       -> $STATE_DIR"
echo
echo "One-time setup: read $DEST/references/setup.md"
echo "(enable Remote Login on the Mac, join Tailscale, generate a key,"
echo " trust it on the Mac, then fill in $STATE_DIR/config)"
