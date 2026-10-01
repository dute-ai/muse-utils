#!/usr/bin/env python3
"""
Read-only BLE probe for the Lifesmart / FitShow treadmill console.

Steps:
  1. Scan for the treadmill (advertises as TM55... per the manual).
  2. Connect and enumerate GATT services / characteristics.
  3. Report whether FTMS (0x1826) or FitShow (0xFFF0) is present.
  4. For FitShow: subscribe to notifications, send SYS_STATUS / SYS_INFO
     polls, and dump raw frames so we can verify parsing against the
     console display.  NEVER sends any control command.

Usage:
    ./venv/bin/python probe.py            # scan + probe (30s capture)
    ./venv/bin/python probe.py --scan-only
"""
import argparse
import asyncio
import sys

from bleak import BleakClient, BleakScanner

FITSHOW_SVC = "0000fff0-0000-1000-8000-00805f9b34fb"
FTMS_SVC = "0000fff0-0000-1000-8000-00805f9b34fb".replace("fff0", "1826")

HDR, FTR = 0x02, 0x03
SYS_STATUS, SYS_INFO = 0x51, 0x50
INFO_MODEL, INFO_SPEED, INFO_INCLINE = 0x00, 0x02, 0x03


def frame(payload: bytes) -> bytes:
    fcs = 0
    for b in payload:
        fcs ^= b
    return bytes([HDR]) + payload + bytes([fcs, FTR])


def parse(raw: bytes):
    if len(raw) < 4 or raw[0] != HDR or raw[-1] != FTR:
        return f"INVALID len={len(raw)} hex={raw.hex(' ')}"
    fcs = 0
    for b in raw[1:-2]:
        fcs ^= b
    ok = "OK " if fcs == raw[-2] else "BAD-FCS "
    cmd, par = raw[1], raw[2]
    names = {0x50: "SYS_INFO", 0x51: "SYS_STATUS", 0x52: "SYS_DATA", 0x53: "SYS_CONTROL"}
    status = {0: "NORMAL", 1: "END", 2: "START", 3: "RUNNING", 4: "STOP",
              5: "ERROR", 6: "SAFETY", 7: "STUDY", 10: "PAUSED"}
    extra = ""
    if cmd == 0x51 and par in (3, 4, 10, 1) and len(raw) >= 8:
        extra = f" speed={raw[3] / 10.0:.1f}mph incline={raw[4] if raw[4] < 128 else raw[4] - 256}%"
    elif cmd == 0x51:
        extra = f" status={status.get(par, par)}"
    return f"{ok}{names.get(cmd, hex(cmd))} par={par}{extra} raw={raw.hex(' ')}"


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scan-only", action="store_true")
    ap.add_argument("--name", default="TM", help="advertised-name prefix to match")
    ap.add_argument("--capture", type=float, default=30.0)
    args = ap.parse_args()

    print(f"Scanning for BLE devices named like '{args.name}*' ...", flush=True)
    found = await BleakScanner.discover(timeout=12.0, return_adv=True)
    cands = [(d, adv.rssi) for d, adv in found.values()
             if (d.name or "").upper().startswith(args.name.upper())]
    if not cands:
        print("No match. All devices seen:")
        rows = [(dev, adv.rssi) for dev, adv in found.values()]
        for dev, rssi in sorted(rows, key=lambda r: (r[1] if r[1] is not None else -999),
                                reverse=True):
            print(f"  {dev.address}  RSSI {rssi}  {dev.name}")
        sys.exit(1)
    tgt, tgt_rssi = max(cands, key=lambda c: c[1] if c[1] is not None else -999)
    print(f"Target: {tgt.address}  RSSI {tgt_rssi}  {tgt.name}", flush=True)
    if args.scan_only:
        return

    async with BleakClient(tgt.address, timeout=15.0) as client:
        print("Connected. Services:")
        fitshow_write = fitshow_notify = None
        for svc in client.services:
            print(f"  svc {svc.uuid}")
            for ch in svc.characteristics:
                props = ",".join(ch.properties)
                print(f"    char {ch.uuid}  [{props}]")
                if svc.uuid == FITSHOW_SVC:
                    if "write" in ch.properties and fitshow_write is None:
                        fitshow_write = ch
                    if "notify" in ch.properties and fitshow_notify is None:
                        fitshow_notify = ch
        svcs = {s.uuid for s in client.services}
        print(f"FTMS present: {FTMS_SVC in svcs}   FitShow present: {FITSHOW_SVC in svcs}")

        if fitshow_notify and fitshow_write:
            print(f"Using write={fitshow_write.uuid} notify={fitshow_notify.uuid}")
            got = asyncio.Event()

            def on_notify(_h, data: bytes):
                print("  <<", parse(bytes(data)), flush=True)
                got.set()

            await client.start_notify(fitshow_notify.uuid, on_notify)
            for label, payload in [
                ("SYS_STATUS poll", bytes([SYS_STATUS])),
                ("SYS_INFO model", bytes([SYS_INFO, INFO_MODEL])),
                ("SYS_INFO speed range", bytes([SYS_INFO, INFO_SPEED])),
                ("SYS_INFO incline range", bytes([SYS_INFO, INFO_INCLINE])),
            ]:
                print(f">> {label}: {frame(payload).hex(' ')}", flush=True)
                await client.write_gatt_char(fitshow_write.uuid, frame(payload), response=True)
                await asyncio.sleep(2.0)
            print(f"Capturing notifications for {args.capture:.0f}s "
                  "(change speed/incline on the console now to see frames)...", flush=True)
            await asyncio.sleep(args.capture)
            await client.stop_notify(fitshow_notify.uuid)
        else:
            print("FitShow service/chars not found — capture skipped.")


if __name__ == "__main__":
    asyncio.run(main())
