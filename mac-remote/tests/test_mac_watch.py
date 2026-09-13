#!/usr/bin/env python3
"""Offline unit tests for mac-watch's state handling (no Mac needed)."""
import importlib.util
import os
import sys
import tempfile
from importlib.machinery import SourceFileLoader

fails = 0


def ok(msg):
    print(f"  ok: {msg}")


def fail(msg):
    global fails
    fails += 1
    print(f"  FAIL: {msg}")


HERE = os.path.dirname(os.path.abspath(__file__))

# MAC_REMOTE_STATE_DIR must be set before import: the module reads env at load.
tmp_state = tempfile.mkdtemp()
os.environ["MAC_REMOTE_STATE_DIR"] = tmp_state

loader = SourceFileLoader("mac_watch",
                          os.path.join(HERE, "..", "bin", "mac-watch"))
spec = importlib.util.spec_from_file_location("mac_watch", loader.path,
                                              loader=loader)
mw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mw)

# 1. env override wins
if mw.state_dir() == tmp_state:
    ok("state_dir respects MAC_REMOTE_STATE_DIR")
else:
    fail(f"state_dir env override: got {mw.state_dir()!r}")

# 2. save/load roundtrip, file lands under <state>/watch/
st = {"target": "demo:0.1", "last": "2026-09-13T00:00:00", "lines": ["a", "b"]}
mw.save_state("demo:0.1", st)
if mw.load_state("demo:0.1") == st:
    ok("save/load roundtrip")
else:
    fail("save/load roundtrip")
if os.path.isfile(os.path.join(tmp_state, "watch", "demo_0.1.json")):
    ok("state file at <state>/watch/demo_0.1.json")
else:
    fail("state file misplaced: " + str(os.listdir(os.path.join(tmp_state, "watch"))))

# 3. unknown watch entry loads as empty (no crash on first check)
if mw.load_state("never-seen") == {}:
    ok("unknown entry loads as {}")
else:
    fail("unknown entry should load as {}")

# 4. without the env var and without a checkout state dir,
#    falls back to ~/workspace/muse-utils/state
import shutil

fake_bin = tempfile.mkdtemp()
shutil.copy(os.path.join(HERE, "..", "bin", "mac-watch"),
            os.path.join(fake_bin, "mac-watch"))
loader2 = SourceFileLoader("mac_watch2", os.path.join(fake_bin, "mac-watch"))
spec2 = importlib.util.spec_from_file_location("mac_watch2", loader2.path,
                                               loader=loader2)
del os.environ["MAC_REMOTE_STATE_DIR"]
fake_home = tempfile.mkdtemp()
os.environ["HOME"] = fake_home
mw2 = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(mw2)
expected = os.path.join(fake_home, "workspace", "muse-utils", "state")
if mw2.state_dir() == expected:
    ok("fallback to ~/workspace/muse-utils/state")
else:
    fail(f"fallback: got {mw2.state_dir()!r}, want {expected!r}")

sys.exit(1 if fails else 0)
