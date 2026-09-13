#!/bin/bash
# test_install.sh — install.sh installs all skills, one skill, errors on
# unknown names, and never touches state/.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

# Isolated HOME so tests never touch the real ~/workspace/skills.
TMP_HOME="$(mktemp -d)"
export HOME="$TMP_HOME"
trap 'rm -rf "$TMP_HOME"' EXIT

# --- full install ---
bash "$REPO/install.sh" >/dev/null 2>&1
for f in mac-remote/bin/mac-ssh mac-remote/bin/mac-tmux mac-remote/bin/mac-watch \
         mac-remote/SKILL.md youtube-lounge/yt-tv youtube-lounge/SKILL.md; do
    if [ -x "$HOME/workspace/skills/$f" ] || [ -f "$HOME/workspace/skills/$f" ]; then
        ok "installed: $f"
    else
        fail "missing after install: $f"
    fi
done
[ -x "$HOME/workspace/skills/youtube-lounge/yt-tv" ] \
    && ok "yt-tv is executable" || fail "yt-tv is not executable"
diff -r "$REPO/skills/mac-remote" "$HOME/workspace/skills/mac-remote" >/dev/null 2>&1 \
    && ok "mac-remote matches repo" || fail "mac-remote differs from repo"
diff -r "$REPO/skills/youtube-lounge" "$HOME/workspace/skills/youtube-lounge" >/dev/null 2>&1 \
    && ok "youtube-lounge matches repo" || fail "youtube-lounge differs from repo"

# --- single-skill install ---
rm -rf "$HOME/workspace/skills"
bash "$REPO/install.sh" mac-remote >/dev/null 2>&1
[ -d "$HOME/workspace/skills/mac-remote" ] \
    && ok "single install keeps mac-remote" || fail "single install lost mac-remote"
[ ! -e "$HOME/workspace/skills/youtube-lounge" ] \
    && ok "single install skips youtube-lounge" || fail "single install leaked youtube-lounge"

# --- unknown skill ---
if bash "$REPO/install.sh" no-such-skill >/dev/null 2>&1; then
    fail "unknown skill should exit nonzero"
else
    ok "unknown skill exits nonzero"
fi

# --- state/ is never modified ---
mkdir -p "$REPO/state"
echo sentinel > "$REPO/state/.test-sentinel"
bash "$REPO/install.sh" >/dev/null 2>&1
if [ "$(cat "$REPO/state/.test-sentinel" 2>/dev/null)" = "sentinel" ]; then
    ok "reinstall leaves state/ alone"
else
    fail "reinstall modified state/"
fi
rm -f "$REPO/state/.test-sentinel"

[ "$fails" -eq 0 ]
