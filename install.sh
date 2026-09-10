#!/bin/bash
# install.sh — install the mac-remote skill into this Muse VM.
# Safe to re-run: it cleanly reinstalls the skill (state/ is untouched).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$REPO_ROOT/skills/mac-remote"
DEST="$HOME/workspace/skills/mac-remote"
STATE_DIR="$REPO_ROOT/state"

[ -d "$SKILL_SRC" ] || { echo "skill source not found: $SKILL_SRC" >&2; exit 1; }

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SKILL_SRC/." "$DEST/"
chmod +x "$DEST/bin/"*
mkdir -p "$STATE_DIR"
[ -f "$STATE_DIR/config" ] || printf '# MAC_REMOTE_USER=\n# MAC_REMOTE_HOST=\n# MAC_SSH_KEY=\n# MAC_REMOTE_TMUX=\n' > "$STATE_DIR/config"

echo "Installed skill -> $DEST"
echo "State dir       -> $STATE_DIR"
echo
echo "One-time setup: read $DEST/references/setup.md"
echo "(enable Remote Login on the Mac, join Tailscale, generate a key,"
echo " trust it on the Mac, then fill in $STATE_DIR/config)"
