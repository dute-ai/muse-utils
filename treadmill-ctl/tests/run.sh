#!/bin/bash
# run.sh — run this utility's tests. Standalone: works from a lone copy of
# the treadmill-ctl/ directory. No Bluetooth hardware needed.
set -u
cd "$(dirname "$0")"
pass=0; failed=0
for t in test_treadmill_ctl.sh; do
    echo "== $t"
    if ./"$t"; then pass=$((pass+1)); else failed=$((failed+1)); fi
    echo
done
echo "suites: $pass passed, $failed failed"
[ "$failed" -eq 0 ]
