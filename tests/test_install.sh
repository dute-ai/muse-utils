#!/bin/bash
# test_install.sh — installers put the right files in the right places:
# full install, single-utility install, standalone utility install (copied
# out of the repo, the "clone just this util" case), unknown names, and
# state/ is never wiped.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

# Isolated HOME so tests never touch the real ~/workspace/skills.
TMP_HOME="$(mktemp -d)"
export HOME="$TMP_HOME"
trap 'rm -rf "$TMP_HOME"' EXIT

check_installed() { # $1 = util name; verifies payload matches the repo copy
    local util="$1"
    local dest="$HOME/workspace/skills/$util"
    local bad=0
    for f in $(cd "$REPO/$util" && find SKILL.md bin yt-tv references -type f -not -path "*/__pycache__/*" 2>/dev/null); do
        if [ -f "$dest/$f" ] && cmp -s "$REPO/$util/$f" "$dest/$f"; then
            ok "installed $util/$f matches repo"
        else
            fail "installed $util/$f missing or differs"; bad=1
        fi
    done
    for f in README.md install.sh state; do
        [ -e "$dest/$f" ] && { fail "installed $util should not contain $f"; bad=1; }
    done
    [ "$bad" -eq 0 ] && ok "installed $util payload clean"
    [ -x "$dest/bin/mac-ssh" ] 2>/dev/null || [ "$util" != "mac-remote" ] || fail "$util/bin/mac-ssh not executable"
}

# --- full install from repo root ---
bash "$REPO/install.sh" >/dev/null 2>&1
check_installed mac-remote
check_installed youtube-lounge
[ -x "$HOME/workspace/skills/youtube-lounge/yt-tv" ] \
    && ok "yt-tv is executable" || fail "yt-tv is not executable"
[ -f "$HOME/workspace/skills/mac-remote/.state-dir" ] \
    && ok ".state-dir recorded" || fail ".state-dir missing"
grep -q "mac-remote/state" "$HOME/workspace/skills/mac-remote/.state-dir" \
    && ok ".state-dir points at utility state" || fail ".state-dir content wrong"

# --- single-utility install from repo root ---
rm -rf "$HOME/workspace/skills"
bash "$REPO/install.sh" mac-remote >/dev/null 2>&1
[ -d "$HOME/workspace/skills/mac-remote" ] \
    && ok "single install keeps mac-remote" || fail "single install lost mac-remote"
[ ! -e "$HOME/workspace/skills/youtube-lounge" ] \
    && ok "single install skips youtube-lounge" || fail "single install leaked youtube-lounge"

# --- standalone: copy just the utility dir elsewhere, install from there ---
rm -rf "$HOME/workspace/skills"
STANDALONE="$(mktemp -d)/mac-remote"
cp -r "$REPO/mac-remote" "$STANDALONE"
bash "$STANDALONE/install.sh" >/dev/null 2>&1
[ -f "$HOME/workspace/skills/mac-remote/SKILL.md" ] \
    && ok "standalone install works" || fail "standalone install broken"
[ -d "$STANDALONE/state" ] \
    && ok "standalone state next to utility" || fail "standalone state misplaced"
[ "$(cat "$HOME/workspace/skills/mac-remote/.state-dir")" = "$STANDALONE/state" ] \
    && ok ".state-dir tracks standalone location" || fail ".state-dir wrong for standalone"

# --- unknown utility ---
if bash "$REPO/install.sh" no-such-skill >/dev/null 2>&1; then
    fail "unknown utility should exit nonzero"
else
    ok "unknown utility exits nonzero"
fi

# --- state/ is never wiped by reinstall ---
mkdir -p "$REPO/mac-remote/state"
echo sentinel > "$REPO/mac-remote/state/.test-sentinel"
bash "$REPO/install.sh" >/dev/null 2>&1
if [ "$(cat "$REPO/mac-remote/state/.test-sentinel" 2>/dev/null)" = "sentinel" ]; then
    ok "reinstall leaves state/ alone"
else
    fail "reinstall modified state/"
fi
rm -f "$REPO/mac-remote/state/.test-sentinel"

[ "$fails" -eq 0 ]
