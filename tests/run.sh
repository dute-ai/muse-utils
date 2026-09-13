#!/bin/bash
# run.sh — run the whole test suite: repo-level tests plus each utility's
# own tests/<util>/tests/run.sh. Exit 0 iff everything passes.
# Run this before every push: ./tests/run.sh
set -u
cd "$(dirname "$0")"
REPO="$(cd .. && pwd)"

pass=0; failed=0
run_suite() { # $1 = label, $2 = script
    echo "== $1"
    if bash "$2"; then pass=$((pass+1)); else failed=$((failed+1)); fi
    echo
}

run_suite "tests/test_install.sh" test_install.sh
run_suite "tests/test_docs.sh" test_docs.sh
run_suite "tests/test_scripts.sh" test_scripts.sh
for u in "$REPO"/*/; do
    if [ -x "$u/tests/run.sh" ]; then
        run_suite "$(basename "$u")/tests/run.sh" "$u/tests/run.sh"
    fi
done

echo "suites: $pass passed, $failed failed"
[ "$failed" -eq 0 ]
