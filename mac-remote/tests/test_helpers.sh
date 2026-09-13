#!/bin/bash
# test_helpers.sh — syntax checks and offline CLI validation for the
# mac-remote helpers (nothing here touches the network).
UTIL="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

for f in "$UTIL/install.sh" "$UTIL/bin/mac-ssh" "$UTIL/bin/mac-tmux"; do
    if bash -n "$f" 2>/dev/null; then ok "bash -n: ${f#$UTIL/}";
    else fail "bash syntax: ${f#$UTIL/}"; fi
done

# no args -> usage error, no SSH attempted
out="$("$UTIL/bin/mac-tmux" 2>&1)"; code=$?
if [ "$code" -ne 0 ] && [[ "$out" == *"usage: mac-tmux"* ]]; then
    ok "mac-tmux no args prints usage (exit $code)"
else
    fail "mac-tmux no args: exit=$code out=$out"
fi

# unknown subcommand -> clean error, no SSH attempted
out="$("$UTIL/bin/mac-tmux" frobnicate 2>&1)"; code=$?
if [ "$code" -ne 0 ] && [[ "$out" == *"unknown command"* ]]; then
    ok "mac-tmux rejects unknown subcommand"
else
    fail "mac-tmux unknown subcommand: exit=$code out=$out"
fi

# missing subcommand args -> usage error, no SSH attempted
out="$("$UTIL/bin/mac-tmux" new onlyname 2>&1)"; code=$?
if [ "$code" -ne 0 ] && [[ "$out" == *"new <name> <dir>"* ]]; then
    ok "mac-tmux new validates args"
else
    fail "mac-tmux new arg check: exit=$code out=$out"
fi

[ "$fails" -eq 0 ]
