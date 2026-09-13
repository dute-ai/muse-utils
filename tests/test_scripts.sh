#!/bin/bash
# test_scripts.sh — repo-level script checks (root install.sh and the test
# files themselves). Each utility's own scripts are covered by its
# <util>/tests/run.sh.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

for f in "$REPO/install.sh" "$REPO"/tests/*.sh; do
    if bash -n "$f" 2>/dev/null; then ok "bash -n: ${f#$REPO/}";
    else fail "bash syntax: ${f#$REPO/}"; fi
done

[ "$fails" -eq 0 ]
