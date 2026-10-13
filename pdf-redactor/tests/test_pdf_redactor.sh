#!/bin/bash
# test_pdf_redactor.sh — hardware-free, network-free tests:
#   1. py_compile every shipped .py
#   2. detector unit tests (PyMuPDF stubbed — detectors are stdlib-only):
#      SSA/Luhn/ABA checksums must accept real formats and reject decoys
#   3. LLM reply parser: verbatim-in-text filter, malformed/empty replies
#   4. end-to-end on the planted-PII sample, when PyMuPDF is importable:
#      patterns-only run (8 found, 0 remaining, decoy + income untouched)
#      and a mock-LLM run (name caught on both pages, hallucination dropped)
# Set PDF_REDACTOR_PYTHON to the python to test with (default python3).
set -u
cd "$(dirname "$0")/.."
PY="${PDF_REDACTOR_PYTHON:-python3}"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

for f in redact.py make_sample.py tests/mock_openai_server.py; do
    if "$PY" -m py_compile "$f"; then ok "py_compile $f"; else fail "py_compile $f"; fi
done
rm -rf __pycache__ tests/__pycache__

if "$PY" - <<'EOF'
import sys, types
sys.modules["pymupdf"] = types.ModuleType("pymupdf")  # detectors never touch it
sys.path.insert(0, ".")
import redact

def types_of(text):
    return [t for t, _ in redact.detect_patterns(text)]

# SSN: SSA rules — valid shape caught, 666 area rejected
assert "ssn" in types_of("SSN: 123-45-6789")
assert "ssn" not in types_of("SSN: 666-45-6789")
# card: Luhn — the classic test Visa passes, one digit off fails
assert "credit_card" in types_of("Card: 4111-1111-1111-1111")
assert "credit_card" not in types_of("Card: 4111-1111-1111-1112")
# routing: ABA checksum — JPMorgan's real 021000021 passes, the
# sequential decoy 123456789 fails and must NOT be flagged at all
assert "routing_number" in types_of("Routing: 021000021")
assert redact.detect_patterns("Ref: 123456789") == []
# phone / email / keyword account number
assert "phone" in types_of("Phone: (650) 555-0142")
assert "email" in types_of("Email: fake.taxpayer@example.com")
assert ("account_number", "123456789012") in redact.detect_patterns(
    "Account number: 123456789012")
# income figures are not PII to the patterns
assert redact.detect_patterns("Total income 312,908") == []

# LLM reply parser: only verbatim in-text values survive; junk -> []
text = "Name: John Q Taxpayer, SSN 123-45-6789"
assert redact._parse_llm_values('["John Q Taxpayer"]', text) == [("llm", "John Q Taxpayer")]
assert redact._parse_llm_values('["999-99-9999"]', text) == []      # hallucination
assert redact._parse_llm_values(None, text) == []                   # reasoning model, empty content
assert redact._parse_llm_values("", text) == []
assert redact._parse_llm_values("not json at all", text) == []
print("detector + parser checks ok")
EOF
then ok "detector + LLM-parser unit tests"; else fail "detector + LLM-parser unit tests"; fi

# --- end-to-end (needs real PyMuPDF) ---
if ! "$PY" -c "import pymupdf" >/dev/null 2>&1; then
    echo "  skip: end-to-end sample run (PyMuPDF not importable by $PY;"
    echo "        set PDF_REDACTOR_PYTHON to a python that has it)"
else
    TMP="$(mktemp -d)"
    MOCK_PID=""
    trap 'rm -rf "$TMP"; [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null' EXIT
    cp make_sample.py redact.py tests/mock_openai_server.py "$TMP/"
    if ( cd "$TMP" \
        && "$PY" make_sample.py >/dev/null \
        && "$PY" redact.py sample_return.pdf -o out_patterns.pdf \
             --report rep_patterns.json >/dev/null ); then
        ( cd "$TMP" && exec "$PY" mock_openai_server.py ) &
        MOCK_PID=$!
        sleep 1
        ( cd "$TMP" && "$PY" redact.py sample_return.pdf -o out_llm.pdf \
            --backend openai --base-url http://127.0.0.1:18080 \
            --llm-model mock --report rep_llm.json >/dev/null )
        kill "$MOCK_PID" 2>/dev/null; MOCK_PID=""
        if "$PY" - "$TMP" <<'EOF'
import json, sys
import pymupdf
tmp = sys.argv[1]
rep = json.load(open(f"{tmp}/rep_patterns.json"))
assert rep["found_total"] == 8, rep
assert rep["remaining_after_redaction"] == 0, rep
text = "\n".join(p.get_text() for p in pymupdf.open(f"{tmp}/out_patterns.pdf"))
assert "123456789" in text          # ABA-failing decoy survives
assert "312,908" in text            # income figures survive
assert "John Q Taxpayer" in text    # patterns alone can't know a name
rep = json.load(open(f"{tmp}/rep_llm.json"))
assert rep["found_total"] == 10, rep   # 8 patterns + name on both pages
assert rep["remaining_after_redaction"] == 0, rep
text = "\n".join(p.get_text() for p in pymupdf.open(f"{tmp}/out_llm.pdf"))
assert "John Q Taxpayer" not in text   # LLM pass caught it, both pages
assert "999-99-9999" not in text       # hallucinated value never used
print("e2e checks ok")
EOF
        then ok "end-to-end sample run (patterns + mock LLM)"; else fail "end-to-end sample run"; fi
    else
        fail "end-to-end sample run (setup)"
    fi
fi

[ "$fails" -eq 0 ]
