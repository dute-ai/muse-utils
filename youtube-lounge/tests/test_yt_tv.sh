#!/bin/bash
# test_yt_tv.sh — syntax check and offline CLI dispatch tests for yt-tv.
# Pairing and playback need YouTube; everything here runs without network.
UTIL="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

bash -n "$UTIL/install.sh" 2>/dev/null \
    && ok "bash -n: install.sh" || fail "bash syntax: install.sh"

if python3 -m py_compile "$UTIL/yt-tv" 2>/dev/null; then
    ok "py_compile: yt-tv"
else
    fail "py_compile: yt-tv"
fi

YT="$UTIL/yt-tv"
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
