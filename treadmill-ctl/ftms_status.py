#!/usr/bin/env python3
"""Read-only FTMS status check against TM4500.

Reads features + subscribes to treadmill-data notifications for N seconds,
parses reported instantaneous speed (km/h -> mph) and inclination (%).
Does NOT send any control commands.
"""
import argparse, asyncio, struct, sys

TARGET_PREFIX = "TM"
FTMS = "00001826-0000-1000-8000-00805f9b34fb"
C_TM_DATA   = "00002ada-0000-1000-8000-00805f9b34fb"  # notify
C_FEATURES  = "00002acc-0000-1000-8000-00805f9b34fb"  # read
C_TR_STATUS = "00002acd-0000-1000-8000-00805f9b34fb"  # notify

def parse_tm_data(payload: bytes):
    flags, = struct.unpack_from("<H", payload, 0)
    off = 2
    speed_kph, = struct.unpack_from("<H", payload, off); off += 2
    incl = ramp = None
    # walk optional fields in flag order
    if flags & (1<<1): off += 2   # avg speed
    if flags & (1<<2): off += 3   # total distance (uint24)
    if flags & (1<<3):
        incl, = struct.unpack_from("<h", payload, off); off += 2
        ramp, = struct.unpack_from("<h", payload, off); off += 2
    return flags, speed_kph/100.0, (incl/10.0 if incl is not None else None)

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--capture", type=float, default=15.0)
    args = ap.parse_args()
    from bleak import BleakScanner, BleakClient

    print("Scanning for BLE devices named like 'TM*' ...", flush=True)
    advs = await BleakScanner.discover(timeout=8.0, return_adv=True)
    target = None
    for dev, ad in advs.values():
        name = (ad.local_name or "").strip()
        if name.upper().startswith(TARGET_PREFIX):
            target = dev; break
    if not target:
        print("No TM* device found."); return 1
    print(f"Target: {target.address}  {(ad.local_name or '').strip()}", flush=True)

    seen = {}
    def on_tm(_, data: bytearray):
        flags, kph, incl = parse_tm_data(bytes(data))
        mph = kph * 0.621371
        seen["flags"] = flags; seen["mph"] = mph; seen["incline"] = incl

    async with BleakClient(target, timeout=20.0) as c:
        try:
            feats = bytes(await c.read_gatt_char(C_FEATURES))
            print(f"FTMS features flags: 0x{struct.unpack('<I', feats[:4])[0]:08x}")
        except Exception as e:
            print(f"features read failed: {e}")
        await c.start_notify(C_TM_DATA, on_tm)
        print(f"listening {args.capture:.0f}s ...", flush=True)
        await asyncio.sleep(args.capture)
        await c.stop_notify(C_TM_DATA)
    if seen:
        print(f"REPORTED speed={seen['mph']:.2f} mph  incline={seen['incline'] if seen['incline'] is not None else 'n/a'}%")
    else:
        print("No treadmill-data notifications received (machine may not broadcast while idle).")
    return 0

if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
