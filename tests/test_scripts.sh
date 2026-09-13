#!/bin/bash
# test_scripts.sh — syntax-check every script and smoke-test yt-tv's CLI
# dispatch without touching the network (pairing/playback need YouTube).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

# --- bash syntax: *.sh files plus bin/ scripts with a bash/sh shebang ---
while IFS= read -r f; do
    if bash -n "$f" 2>/dev/null; then ok "bash -n: ${f#$REPO/}";
    else fail "bash syntax: ${f#$REPO/}"; fi
done < <(
    find "$REPO" -name "*.sh" -not -path "*/.git/*" -not -path "*/state/*" -not -path "*/tests/*"
    find "$REPO" -path "*/bin/*" -type f -not -path "*/.git/*" -not -path "*/tests/*" | while IFS= read -r f; do
        head -1 "$f" | grep -qE '^#!.*\b(bash|sh)\b' && echo "$f"
    done
)

# --- python compiles ---
for py in "$REPO/mac-remote/bin/mac-watch" "$REPO/youtube-lounge/yt-tv"; do
    if python3 -m py_compile "$py" 2>/dev/null; then ok "py_compile: ${py#$REPO/}";
    else fail "py_compile: ${py#$REPO/}"; fi
done

# --- yt-tv CLI dispatch (isolated config dir, no network) ---
YT="$REPO/youtube-lounge/yt-tv"
export YOUTUBE_LOUNGE_DIR="$(mktemp -d)"
trap 'rm -rf "$YOUTUBE_LOUNGE_DIR"' EXIT

# a fake paired TV so dispatch tests don't fail on TV resolution
printf '{"label": "TestTV", "screenId": "x", "loungeToken": "y", "expiration": 0, "name": "t"}' \
    > "$YOUTUBE_LOUNGE_DIR/testtv.json"

out="$("$YT" --tv Nope status 2>&1)"; code=$?
if [ "$code" -ne 0 ] && ! grep -qi "traceback" <<<"$out"; then
    ok "unpaired TV fails gracefully (exit $code, no traceback)"
else
    fail "unpaired TV: exit=$code out=$out"
fi

out="$("$YT" --tv TestTV frobnicate 2>&1)"; code=$?
if [ "$code" -ne 0 ] && [[ "$out" == *"unknown command"* ]]; then
    ok "unknown command rejected"
else
    fail "unknown command: exit=$code out=$out"
fi

out="$("$YT" --tv TestTV play 2>&1)"; code=$?
if [ "$code" -ne 0 ] && [[ "$out" == *"needs an argument"* ]]; then
    ok "missing arg rejected"
else
    fail "missing arg: exit=$code out=$out"
fi

out="$("$YT" pair 2>&1)"; code=$?
if [ "$code" -ne 0 ] && [[ "$out" == *"pair needs --tv"* ]]; then
    ok "pair without --tv rejected"
else
    fail "pair without --tv: exit=$code out=$out"
fi

[ "$fails" -eq 0 ]
