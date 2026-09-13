#!/bin/bash
# run.sh — run the whole test suite. Exit 0 iff everything passes.
# Run this before every push: ./tests/run.sh
set -u
cd "$(dirname "$0")"

pass=0; failed=0
for t in test_*.sh; do
    echo "== $t"
    if bash "$t"; then
        pass=$((pass+1))
    else
        failed=$((failed+1))
    fi
    echo
done

echo "suites: $pass passed, $failed failed"
[ "$failed" -eq 0 ]
