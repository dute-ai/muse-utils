#!/bin/bash
# install.sh — install the skills in this repo into this Muse VM.
# Usage: ./install.sh [skill-name]   (no argument = install all skills)
# Safe to re-run: it cleanly reinstalls each skill without touching state/.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
DEST_ROOT="$HOME/workspace/skills"
STATE_DIR="$REPO_ROOT/state"

[ -d "$SKILLS_SRC" ] || { echo "skills dir not found: $SKILLS_SRC" >&2; exit 1; }

install_one() {
    local SKILL_SRC="$1" NAME DEST
    NAME="$(basename "$SKILL_SRC")"
    DEST="$DEST_ROOT/$NAME"
    rm -rf "$DEST"
    mkdir -p "$DEST"
    cp -R "$SKILL_SRC/." "$DEST/"
    [ -d "$DEST/bin" ] && chmod +x "$DEST/bin/"*
    echo "Installed skill -> $DEST"
}

INSTALLED=""
if [ "${1:-}" != "" ]; then
    [ -d "$SKILLS_SRC/$1" ] || { echo "skill not found: $1 (available: $(ls "$SKILLS_SRC"))" >&2; exit 1; }
    install_one "$SKILLS_SRC/$1"
    INSTALLED="$1"
else
    for SKILL_SRC in "$SKILLS_SRC"/*/; do
        [ -d "$SKILL_SRC" ] || continue
        install_one "$SKILL_SRC"
        INSTALLED="$INSTALLED $(basename "$SKILL_SRC")"
    done
fi

case "$INSTALLED" in
*mac-remote*)
    # mac-remote one-time state dir (SSH config lives here, gitignored)
    mkdir -p "$STATE_DIR"
    [ -f "$STATE_DIR/config" ] || printf '# MAC_REMOTE_USER=\n# MAC_REMOTE_HOST=\n# MAC_SSH_KEY=\n# MAC_REMOTE_TMUX=\n' > "$STATE_DIR/config"
    echo "State dir       -> $STATE_DIR"
    echo
    echo "One-time setup: read $DEST_ROOT/mac-remote/references/setup.md"
    echo "(enable Remote Login on the Mac, join Tailscale, generate a key,"
    echo " trust it on the Mac, then fill in $STATE_DIR/config)"
    ;;
esac

case "$INSTALLED" in
*youtube-lounge*)
    echo
    echo "For youtube-lounge: pair each TV once with the code from its"
    echo "YouTube app (Settings -> Link with TV code):"
    echo "  $DEST_ROOT/youtube-lounge/yt-tv --tv \"My TV\" pair <code>"
    ;;
esac
