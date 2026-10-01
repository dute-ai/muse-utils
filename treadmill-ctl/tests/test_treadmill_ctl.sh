#!/bin/bash
# test_treadmill_ctl.sh — hardware-free tests: syntax, CLI smoke, workout
# validation, and the safety-envelope clamp behavior. Needs only python3.
set -u
cd "$(dirname "$0")/.."
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

for f in treadmill_ctl.py probe.py scan.py ftms_status.py; do
    if python3 -m py_compile "$f"; then ok "py_compile $f"; else fail "py_compile $f"; fi
done
rm -rf __pycache__

if python3 treadmill_ctl.py --help >/dev/null 2>&1; then
    ok "--help exits 0 (no BLE needed)"
else
    fail "--help failed"
fi
if python3 treadmill_ctl.py run --help 2>/dev/null | grep -q -- --workout; then
    ok "run --workout flag present"
else
    fail "run --workout flag missing"
fi

# shipped example workout parses and stays inside the safety caps
if python3 - <<'EOF'
import json
w = json.load(open("workouts/hill_climb_20min.json"))
assert w["segments"], "no segments"
for s in w["segments"]:
    assert s["duration_s"] > 0, f"bad duration: {s}"
    assert s["speed_mph"] <= 4.0, f"over speed cap: {s}"
    assert s["incline_pct"] <= 10.0, f"over incline cap: {s}"
print("example workout within caps")
EOF
then ok "example workout within caps"; else fail "example workout exceeds caps"; fi

# load_workout clamps over-cap segments and flags them (import is BLE-free:
# bleak is only imported lazily inside connect())
if python3 - <<'EOF'
import json, sys
sys.path.insert(0, ".")
import treadmill_ctl
w = {"name": "t", "segments": [{"duration_s": 60, "speed_mph": 9.9, "incline_pct": 25.0}]}
open("/tmp/_treadmill_overcap.json", "w").write(json.dumps(w))
_, segs = treadmill_ctl.load_workout("/tmp/_treadmill_overcap.json")
s = segs[0]
assert (s["mph"], s["incline"], s["clamped"]) == (4.0, 10.0, True), s
print("clamp behavior ok")
EOF
then ok "over-cap segments clamped+flagged"; else fail "clamp behavior"; fi
rm -f /tmp/_treadmill_overcap.json

[ "$fails" -eq 0 ]
