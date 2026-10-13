#!/bin/bash
# run.sh — run this utility's tests. Standalone: works from a lone copy of
# the pdf-redactor/ directory. Detector tests need only python3; the
# end-to-end sample run also needs PyMuPDF and skips without it.
set -u
cd "$(dirname "$0")"
pass=0; failed=0
for t in test_pdf_redactor.sh; do
    echo "== $t"
    if ./"$t"; then pass=$((pass+1)); else failed=$((failed+1)); fi
    echo
done
echo "suites: $pass passed, $failed failed"
[ "$failed" -eq 0 ]
