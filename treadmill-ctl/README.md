# Treadmill BLE control (Mac)

Drives the Lifesmart incline treadmill (BLE name `TM4500`) from a Mac
over Bluetooth LE. Verified working 2026-09-28 against the physical unit.

## Protocol map (measured, not assumed)

| Function | Protocol | Notes |
|---|---|---|
| Start / stop belt | FTMS (0x1826), control point 0x2AD9 | Verified: belt moves/stops |
| Speed + incline | FitShow vendor service (0xFFF0) | Frame `02 53 02 <mph*10> <incline%> <xor> 03` on 0xFFF2 (write, no response) |
| Read-back | FitShow notify 0xFFF1 | Machine echoes accepted targets as `02 53 02 <mph*10> <incline%> <xor> 03` |
| Emergency stop | FitShow stop `02 53 03 <xor> 03` **then** FTMS stop | Belt-and-suspenders; both sent |

Known quirks of this unit:

- **FTMS set-speed is acked-but-ignored.** The machine returns success for
  FTMS speed commands yet the belt stays at the console's own default
  (0.6 mph). Speed must go through FitShow.
- **First FitShow frame(s) after start are often dropped.** The controller
  writes each target 3x (~200 ms apart, mirroring the qdomyos poll loop),
  waits up to 4 s for a matching echo, and retries up to 3 attempts. A
  target with no matching echo raises instead of proceeding blind.
- Incline is slow mechanically (~15–20 s for 5 %); the console shows the
  in-progress value while the deck is still moving.

Frame format follows the qdomyos-zwift `fitshowtreadmill` driver
(`02` + payload + XOR of payload bytes + `03`).

## One-time setup

1. Python env: Python 3.12+ with `bleak` (`pip install bleak`). A venv
   under the project dir works: `python3 -m venv venv && ./venv/bin/pip install bleak`.
2. **macOS Bluetooth permission** (required, manual step):
   System Settings → Privacy & Security → Bluetooth → enable for **Terminal**.
   BLE scripts must be launched *inside* Terminal.app — the permission is
   attributed to the launching app, so the same command over SSH is denied.
3. The treadmill must be powered on and the Mac within ~10 m of it
   (signal is weak past a room or two; RSSI around −90 dBm at range).
4. Make sure no phone app is currently connected to the treadmill — only one
   BLE central can hold the link.

## Probe first (read-only, moves nothing)

```bash
./venv/bin/python probe.py                 # scan + GATT dump
./venv/bin/python ftms_status.py           # FTMS features + 15s state listen
```

Compare the parsed speed/incline against the console display before
trusting anything the scripts report.

## Commands

Run them inside Terminal.app (not over SSH), with `caffeinate -i` so the Mac
doesn't sleep mid-session — a sleeping Mac means a dead control link.

```bash
cd ~/treadmill-ctl
caffeinate -i ./venv/bin/python treadmill_ctl.py status   # read-only check
caffeinate -i ./venv/bin/python treadmill_ctl.py nudge    # supervised: 10s at 1.0 mph
caffeinate -i ./venv/bin/python treadmill_ctl.py speedtest # FTMS start, then 3.0 mph + 5% while running
caffeinate -i ./venv/bin/python treadmill_ctl.py ftest    # FitShow: 2.5 mph + 4% for 20s, echo-verified
caffeinate -i ./venv/bin/python treadmill_ctl.py stop     # emergency stop (FitShow + FTMS)
caffeinate -i ./venv/bin/python treadmill_ctl.py run --workout workouts/hill_climb_20min.json
```

`run` executes a workout JSON: 16 × 75 s segments of 3.0–3.5 mph at 0–8 %
incline (see `workouts/hill_climb_20min.json`), then a 1.5 mph cooldown and
stop. Every segment transition is announced in the terminal before it is
sent, and each target must be echo-verified before the segment timer starts.

`TREADMILL_CONFIRM=GO` in the environment bypasses the `GO` keyboard prompt;
it exists so a supervised remote run can be confirmed in chat by the person
standing at the treadmill. Never use it unattended.

## Safety envelope (enforced in code)

- Hard caps: **4.0 mph**, **10 % incline**. Workout segments above the caps
  are clamped and reported.
- No blind targets: every FitShow speed/incline command requires a matching
  echo on the notify characteristic before proceeding.
- No autonomous start: you type `GO` at the prompt (or confirm in chat, see
  above) before anything moves. Stand on the treadmill, safety clip
  attached, hand near the physical STOP.
- Dual stop path: FitShow stop followed by FTMS stop.

## Failure model (what the code cannot fix)

- A lost BLE link can leave the belt running at its last target — the
  **safety key / clip is the primary emergency stop**, not this script.
- The machine can acknowledge a command without acting on it (observed with
  FTMS speed). The echo check guards FitShow targets; the console display
  remains the ground truth — glance at it on the first run of any new
  workout.
- Keep your hand near the physical STOP for the whole session.

## Files

- `treadmill_ctl.py` — controller (`status` / `stop` / `nudge` /
  `speedtest` / `ftest` / `run`).
- `probe.py` — read-only BLE probe / GATT dump.
- `ftms_status.py` — read-only FTMS features + state listener.
- `scan.py` — quick BLE scan helper.
- `workouts/hill_climb_20min.json` — example 20-min hill workout
  (16 × 75 s, 3.0–3.5 mph, 0–8 %).
- `launch_scan.scpt`, `read_win.scpt` — AppleScript helpers for launching a
  scan inside Terminal.app and reading the window back (used when driving
  this from automation instead of by hand).
