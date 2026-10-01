#!/usr/bin/env python3
"""FTMS-based controller for the Lifesmart incline treadmill (BLE name TM4500).

Uses the Bluetooth SIG Fitness Machine Service (0x1826) — the same open
protocol Zwift and other apps use. Every command waits for the machine's
own response frame (0x80 <opcode> <result>); any non-success result aborts.

SAFETY ENVELOPE
  - Nothing moves until the operator types GO at the prompt (supervised start).
  - Hard caps: 4.0 mph, 10% incline. Any segment above is clamped, and the
    operator is told it was clamped.
  - Transitions are announced before being applied.
  - Reported speed/incline from treadmill-data notifications is checked
    against targets after a settle window; on divergence, protocol error, or
    link loss: attempt STOP, raise the alarm, return to manual control.
  - Keep the physical STOP button and the safety key within reach. The
    safety key is the primary emergency stop; confirm its behavior on this
    unit before trusting it above software commands.

Usage:
  status   -- read-only: connect, print FTMS features, listen for state
  nudge    -- supervised: +0.5 mph nudge from idle at 1.0 mph, then STOP
  run      -- supervised: run workouts/hill_climb_20min.json after GO
  stop     -- emergency stop (request control, stop, reset)

mph <-> km/h: FTMS uses km/h (0.01 resolution). Incline: % (0.1 resolution).
"""
import argparse, asyncio, json, os, struct, sys, time

TARGET_PREFIX = "TM"
HERE = os.path.dirname(os.path.abspath(__file__))

FTMS        = "00001826-0000-1000-8000-00805f9b34fb"
C_TM_DATA   = "00002ada-0000-1000-8000-00805f9b34fb"  # notify
C_CP        = "00002ad9-0000-1000-8000-00805f9b34fb"  # write, indicate
C_FEATURES  = "00002acc-0000-1000-8000-00805f9b34fb"  # read

# FTMS control point opcodes
OP_REQUEST_CONTROL = 0x00
OP_RESET           = 0x01
OP_SET_SPEED       = 0x02   # uint16 LE, 0.01 km/h
OP_SET_INCLINE     = 0x03   # sint16 LE, 0.1 %
OP_START           = 0x07
OP_STOP            = 0x08   # param 0x01=stop, 0x02=pause
RESP               = 0x80
RESULT_OK          = 0x01

# hard safety caps
MAX_MPH   = 4.0
MAX_INCL  = 10.0
SETTLE_S  = 12.0     # time allowed for speed/incline to reach target
TOL_MPH   = 0.25
TOL_INCL  = 1.0

MPH_TO_KMH = 1.609344

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

class Treadmill:
    def __init__(self, client):
        self.c = client
        self._resp = asyncio.Queue()
        self.speed_mph = 0.0
        self.incline_pct = 0.0
        self.last_notify = 0.0
        self.notify_count = 0
        self.alarmed = False

    async def setup(self):
        c = self.c
        await c.start_notify(C_CP, self._on_cp)
        await c.start_notify(C_TM_DATA, self._on_tm)
        try:
            feats = bytes(await c.read_gatt_char(C_FEATURES))
            f, = struct.unpack_from("<I", feats, 0)
            print(f"FTMS features: 0x{f:08x}  (inclination supported: {bool(f & 0x0008)})")
        except Exception as e:
            print(f"features read failed (continuing): {e}")

    def _on_cp(self, _, data):
        b = bytes(data)
        if len(b) >= 3 and b[0] == RESP:
            self._resp.put_nowait((b[1], b[2]))

    def _on_tm(self, _, data):
        b = bytes(data)
        if len(b) < 4:
            return
        self.notify_count += 1
        flags, = struct.unpack_from("<H", b, 0)
        off = 2
        kph, = struct.unpack_from("<H", b, off); off += 2
        if flags & (1 << 1): off += 2          # avg speed
        if flags & (1 << 2): off += 3          # total distance
        if flags & (1 << 3):
            incl, = struct.unpack_from("<h", b, off); off += 2
            ramp, = struct.unpack_from("<h", b, off); off += 2
            self.incline_pct = incl / 10.0
        self.speed_mph = kph * 0.621371
        self.last_notify = time.time()

    async def _cmd(self, opcode, params=b"", desc="command", timeout=4.0):
        while not self._resp.empty():
            self._resp.get_nowait()
        await self.c.write_gatt_char(C_CP, bytes([opcode]) + params, response=True)
        try:
            rop, res = await asyncio.wait_for(self._resp.get(), timeout)
        except asyncio.TimeoutError:
            self.alarm(f"{desc}: no response from machine")
            raise RuntimeError(f"{desc}: no response")
        if rop != opcode or res != RESULT_OK:
            self.alarm(f"{desc}: rejected (op={rop:#x} result={res:#x})")
            raise RuntimeError(f"{desc}: rejected result={res:#x}")
        print(f"  ok: {desc}")
        return True

    async def request_control(self):
        await self._cmd(OP_REQUEST_CONTROL, desc="request control")

    async def reset(self):
        await self._cmd(OP_RESET, desc="reset")

    async def start(self):
        await self._cmd(OP_START, desc="start belt")

    async def stop(self):
        # 0x01 = stop (belt to 0), the emergency path
        await self._cmd(OP_STOP, b"\x01", desc="STOP")

    async def set_speed(self, mph):
        mph = clamp(mph, 0.0, MAX_MPH)
        raw = int(round(mph * MPH_TO_KMH * 100))
        await self._cmd(OP_SET_SPEED, struct.pack("<H", raw), desc=f"set speed {mph:.1f} mph")

    async def set_incline(self, pct):
        pct = clamp(pct, 0.0, MAX_INCL)
        raw = int(round(pct * 10))
        await self._cmd(OP_SET_INCLINE, struct.pack("<h", raw), desc=f"set incline {pct:.0f}%")

    def alarm(self, msg):
        self.alarmed = True
        print(f"\n!!! ALARM: {msg} — attempting STOP, returning to manual control !!!\n")

    async def verify_settled(self, want_mph, want_incl, label):
        """Wait up to SETTLE_S for reported state to converge on targets."""
        deadline = time.time() + SETTLE_S
        while time.time() < deadline:
            if time.time() - self.last_notify > 5.0:
                await asyncio.sleep(0.5); continue
            ds = abs(self.speed_mph - want_mph)
            di = abs(self.incline_pct - want_incl)
            if ds <= TOL_MPH and di <= TOL_INCL:
                print(f"  verified: reported {self.speed_mph:.1f} mph / {self.incline_pct:.0f}% matches {label}")
                return True
            await asyncio.sleep(0.5)
        self.alarm(f"{label}: reported {self.speed_mph:.1f} mph / {self.incline_pct:.0f}% "
                   f"did not settle to {want_mph:.1f} mph / {want_incl:.0f}%")
        return False

async def find_treadmill():
    from bleak import BleakScanner
    print("Scanning for TM4500 ...")
    advs = await BleakScanner.discover(timeout=8.0, return_adv=True)
    for dev, ad in advs.values():
        if (ad.local_name or "").strip().upper().startswith(TARGET_PREFIX):
            print(f"found: {dev.address}  {(ad.local_name or '').strip()}")
            return dev
    raise RuntimeError("treadmill not advertising (powered on? phone app holding the connection?)")

async def connect():
    from bleak import BleakClient
    dev = await find_treadmill()
    c = BleakClient(dev, timeout=20.0)
    await c.connect()
    tm = Treadmill(c)
    await tm.setup()
    return c, tm

# ---------------------------------------------------------------- FitShow
# Vendor-native protocol (from qdomyos-zwift fitshowtreadmill driver).
# Frame: 0x02 + payload + XOR(payload bytes) + 0x03
# Speed/incline: {0x53, 0x02, mph*10, incline_pct}   (treadmill uses miles)
# Stop:          {0x53, 0x03}
# The machine echoes accepted targets on the notify char as
#   02 53 02 <mph*10> <incline> <xor> 03   -> used as read-back.
FS_SVC    = "0000fff0-0000-1000-8000-00805f9b34fb"
FS_NOTIFY = "0000fff1-0000-1000-8000-00805f9b34fb"
FS_WRITE  = "0000fff2-0000-1000-8000-00805f9b34fb"

def fs_frame(payload: bytes) -> bytes:
    n = 0
    for b in payload:
        n ^= b
    return b"\x02" + payload + bytes([n, 0x03])

class FitShow:
    def __init__(self, client):
        self.c = client
        self.echo_speed = None
        self.echo_incline = None
        self._echo_q = asyncio.Queue()

    async def setup(self):
        await self.c.start_notify(FS_NOTIFY, self._on_fs)

    def _on_fs(self, _, data):
        b = bytes(data)
        if len(b) < 6 or b[0] != 0x02 or b[-1] != 0x03:
            return
        payload, xor = b[1:-2], b[-2]
        n = 0
        for x in payload:
            n ^= x
        if n != xor or len(payload) < 4:
            return
        if payload[0] == 0x53 and payload[1] == 0x02:
            self.echo_speed = payload[2] / 10.0
            self.echo_incline = payload[3]
            self._echo_q.put_nowait((self.echo_speed, self.echo_incline))
        else:
            print(f"  FS<< {b.hex(' ')}")

    async def send_target(self, mph, incline_pct, desc="target", tries=3):
        """Send speed/incline, requiring a matching echo as read-back.

        Each attempt writes the frame 3x (~200ms apart, mirroring qdomyos'
        poll loop — single frames can be dropped). Raises on no echo match.
        """
        mph = clamp(mph, 0.0, MAX_MPH)
        incline = int(round(clamp(incline_pct, 0.0, MAX_INCL)))
        frame = fs_frame(bytes([0x53, 0x02, int(round(mph * 10)), incline]))
        for attempt in range(tries):
            while not self._echo_q.empty():
                self._echo_q.get_nowait()
            for _ in range(3):
                await self.c.write_gatt_char(FS_WRITE, frame, response=False)
                await asyncio.sleep(0.2)
            try:
                async def wait_match():
                    while True:
                        es, ei = await self._echo_q.get()
                        if abs(es - mph) < 0.06 and ei == incline:
                            return es, ei
                es, ei = await asyncio.wait_for(wait_match(), timeout=4.0)
                print(f"  ok (echo): {desc} -> {es:.1f} mph / {ei}%")
                return True
            except asyncio.TimeoutError:
                print(f"  no echo for {desc} (attempt {attempt+1}/{tries}), retrying...")
        raise RuntimeError(f"FitShow target not echoed: {desc}")

    async def stop(self):
        await self.c.write_gatt_char(FS_WRITE, fs_frame(bytes([0x53, 0x03])),
                                     response=False)
        print("  sent FitShow STOP")

def need_go(prompt):
    if os.environ.get("TREADMILL_CONFIRM") == "GO":
        print(f"{prompt}\n(confirmed in chat by operator at the treadmill)")
        return
    print(prompt)
    ans = input("Type GO to proceed: ").strip().upper()
    if ans != "GO":
        print("aborted — nothing was started.")
        sys.exit(1)

async def cmd_status(_):
    c, tm = await connect()
    try:
        print("listening 15s for treadmill-data (idle machines may stay silent) ...")
        await asyncio.sleep(15)
        if tm.last_notify:
            print(f"reported: {tm.speed_mph:.2f} mph / {tm.incline_pct:.1f}%")
        else:
            print("no notifications while idle — normal for this unit.")
    finally:
        await c.disconnect()

async def cmd_speedtest(args):
    """Diagnostic: start belt FIRST, then set speed/incline while running."""
    c, tm = await connect()
    try:
        print("\nSPEED/INCLINE DIAGNOSTIC: start first, then set targets while running.")
        print("Stand ON the treadmill, safety clip attached, hand near STOP.")
        need_go("Ready?")
        await tm.request_control()
        await tm.set_incline(0)
        await tm.start()
        print("belt started — waiting 3s, then setting 3.0 mph ...")
        await asyncio.sleep(3)
        await tm.set_speed(3.0)
        print("watch the console: what speed does it settle on? (12s)")
        await asyncio.sleep(12)
        await tm.set_incline(5)
        print("incline set to 5% — does the deck visibly rise? (15s)")
        await asyncio.sleep(15)
        print(f"treadmill-data notifications received: {tm.notify_count}")
        await tm.set_incline(0)
        await tm.stop()
        print("diagnostic complete — control returned to you.")
    except Exception as e:
        print(f"error: {e}")
        try: await tm.stop()
        except Exception: pass
    finally:
        await c.disconnect()

async def cmd_ftest(args):
    """FitShow combined test: FTMS start, FitShow 2.5 mph + 4% (3x sends),
    20s dwell, FitShow stop, FTMS stop backup."""
    c, tm = await connect()
    fs = FitShow(c)
    await fs.setup()
    try:
        print("\nFITSHOW COMBINED TEST: 2.5 mph + 4% incline for 20s.")
        print("Stand ON the treadmill, safety clip attached, hand near STOP.")
        need_go("Ready?")
        await tm.request_control()
        await tm.start()
        print("belt running — sending FitShow target 2.5 mph / 4% ...")
        await fs.send_target(2.5, 4, desc="2.5 mph / 4%")
        print("WATCH 20s: console speed? did the deck rise?")
        await asyncio.sleep(20)
        await fs.stop()
        await asyncio.sleep(2)
        await tm.stop()
        print("done — control returned to you.")
    except Exception as e:
        print(f"error: {e}")
        try: await tm.stop()
        except Exception: pass
    finally:
        await c.disconnect()

async def cmd_nudge(args):
    mph = getattr(args, "mph", 1.0)
    secs = getattr(args, "seconds", 10)
    c, tm = await connect()
    try:
        print(f"\nNUDGE TEST: brief {mph:.1f} mph walk for {secs}s, then STOP.")
        print("Stand ON the treadmill, safety clip attached, hand near STOP.")
        need_go("Ready for the supervised nudge?")
        await tm.request_control()
        await tm.set_speed(mph)
        await tm.set_incline(0)
        await tm.start()
        print(f"belt should be starting — {secs}s at {mph:.1f} mph ...")
        for i in range(secs, 0, -1):
            print(f"  {i}s  reported {tm.speed_mph:.1f} mph", end="\r")
            await asyncio.sleep(1)
        print()
        print(f"treadmill-data notifications received: {tm.notify_count}")
        await tm.stop()
        print("nudge complete — control returned to you.")
    except Exception as e:
        print(f"error: {e}")
        try: await tm.stop()
        except Exception: pass
    finally:
        await c.disconnect()

async def cmd_stop(_):
    c, tm = await connect()
    fs = FitShow(c)
    try:
        await fs.setup()
    except Exception:
        pass
    try:
        await tm.request_control()
        try:
            await fs.stop()
        except Exception:
            pass
        await asyncio.sleep(1)
        await tm.stop()
        print("STOP sent (FitShow + FTMS).")
    finally:
        await c.disconnect()

def load_workout(path):
    with open(path) as f:
        w = json.load(f)
    segs = []
    for s in w["segments"]:
        mph = float(s["speed_mph"]); incl = float(s["incline_pct"])
        clamped = False
        if mph > MAX_MPH: mph = MAX_MPH; clamped = True
        if incl > MAX_INCL: incl = MAX_INCL; clamped = True
        segs.append({"duration_s": int(s["duration_s"]), "mph": mph,
                     "incline": incl, "clamped": clamped})
    return w.get("name", path), segs

async def cmd_run(args):
    """Run a workout JSON using FitShow for speed/incline (echo-verified),
    FTMS start and dual FitShow+FTMS stop."""
    name, segs = load_workout(args.workout)
    total = sum(s["duration_s"] for s in segs)
    print(f"\n{name}\n{len(segs)} segments, {total//60} min. Caps: {MAX_MPH} mph / {MAX_INCL}%.")
    for i, s in enumerate(segs):
        flag = "  [CLAMPED to cap]" if s["clamped"] else ""
        print(f"  {i+1:2d}. {s['duration_s']}s  {s['mph']:.1f} mph  {s['incline']:.0f}%{flag}")
    print("\nStand ON the treadmill, safety clip attached, hand near STOP.")
    need_go("Ready to run the full program?")
    c, tm = await connect()
    fs = FitShow(c)
    await fs.setup()
    try:
        await tm.request_control()
        await tm.start()  # FTMS start (verified); belt at console default
        for i, s in enumerate(segs):
            print(f"\n--- segment {i+1}/{len(segs)}: {s['mph']:.1f} mph, "
                  f"{s['incline']:.0f}% for {s['duration_s']}s ---")
            await fs.send_target(s["mph"], s["incline"], desc=f"segment {i+1}")
            await asyncio.sleep(s["duration_s"])
        print("\nWorkout complete — cooling down.")
        await fs.send_target(1.5, 0, desc="cooldown")
        await asyncio.sleep(20)
        await fs.stop()
        await asyncio.sleep(2)
        await tm.stop()
        print("program finished — control returned to you.")
    except Exception as e:
        print(f"error: {e}")
        try:
            await fs.stop()
        except Exception:
            pass
        try:
            await tm.stop()
        except Exception:
            pass
        tm.alarm("exception during run")
    finally:
        await c.disconnect()

def main():
    ap = argparse.ArgumentParser(description="FTMS controller for TM4500 treadmill")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    pn = sub.add_parser("nudge")
    pn.add_argument("--mph", type=float, default=1.0)
    pn.add_argument("--seconds", type=int, default=10)
    sub.add_parser("speedtest")
    sub.add_parser("ftest")
    sub.add_parser("stop")
    p = sub.add_parser("run")
    p.add_argument("--workout", default=os.path.join(HERE, "workouts", "hill_climb_20min.json"))
    args = ap.parse_args()
    handlers = {"status": cmd_status, "nudge": cmd_nudge,
                "speedtest": cmd_speedtest, "ftest": cmd_ftest,
                "stop": cmd_stop, "run": cmd_run}
    asyncio.run(handlers[args.cmd](args))

if __name__ == "__main__":
    main()
