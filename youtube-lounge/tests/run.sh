#!/bin/bash
# run.sh — run this utility's tests. Standalone: works from a lone copy of
# the youtube-lounge/ directory.
set -u
cd "$(dirname "$0")"
pass=0; failed=0
for t in test_yt_tv.sh; do
    echo "== $t"
    if ./"$t"; then pass=$((pass+1)); else failed=$((failed+1)); fi
    echo
done
echo "suites: $pass passed, $failed failed"
[ "$failed" -eq 0 ]
