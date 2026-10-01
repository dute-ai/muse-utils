---
name: "treadmill_ctl"
description: "Drive a Lifesmart incline treadmill (BLE name TM4500) from the user's Mac over Bluetooth LE: read-only probe, supervised diagnostics, and JSON-scripted workouts under a hard safety envelope (4.0 mph / 10% caps, echo-verified targets, supervised GO start)."
---

# treadmill-ctl

## Purpose
Control a Lifesmart incline treadmill from the Mac over BLE. The controller
speaks two protocols: FTMS (0x1826, the Bluetooth SIG standard — belt
start/stop) and the vendor FitShow protocol (0xFFF0 — speed/incline with
echo read-back). Nothing moves without a supervised start.

## Tooling
The scripts live next to this file (installed at
`~/workspace/skills/treadmill-ctl/`). They run **on the Mac, not on this
VM** — the VM has no Bluetooth. Drive them through the mac-remote skill:
BLE commands must be launched *inside* Terminal.app via AppleScript
(`do script`), because macOS attributes the Bluetooth permission to the
launching app. The same command over plain SSH is denied with "Bluetooth
is not authorized".

One-time Mac setup (details in `README.md`):
1. Python 3.12+ with `bleak` (`pip install bleak`).
2. System Settings → Privacy & Security → Bluetooth → enable for Terminal.
3. Treadmill powered on, Mac within ~10 m, no phone app holding the BLE link.

Scripts (all run on the Mac):
- `probe.py` — read-only: BLE scan, GATT dump, frame capture. Always run
  first on a new machine; compare the parsed speed/incline against the
  console display.
- `ftms_status.py` — read-only FTMS features + state listen.
- `scan.py` — quick BLE scan helper.
- `treadmill_ctl.py` — the controller:
  - `status` — read-only check
  - `stop` — emergency stop (FitShow stop, then FTMS stop)
  - `nudge [--mph] [--seconds]` — supervised short walk test
  - `speedtest`, `ftest` — supervised protocol diagnostics
  - `run --workout workouts/hill_climb_20min.json` — scripted workout
    (16 × 75 s segments, then cooldown and dual stop)

## Operating Rules
1. **Never run the belt unattended.** `TREADMILL_CONFIRM=GO` bypasses the
   keyboard GO prompt so a supervised run can be confirmed in chat — set it
   only after the user explicitly confirms they are on the belt, safety clip
   attached, hand near STOP. The safety key is the primary emergency stop,
   not this software.
2. Launch inside Terminal.app (`do script`), never over plain SSH.
3. Wrap every session in `caffeinate -i` — a sleeping Mac is a dead control
   link, and a dead link fails hot: the belt keeps its last target.
4. The console display is ground truth. First run of any new workout: probe
   first, then one small nudge at walking speed with a hand over STOP,
   verify, then the full program.
5. `stop` is always safe to send.
6. The repo-root `install.sh` — or the utility's own `install.sh` —
   installs this skill to `~/workspace/skills/`.
