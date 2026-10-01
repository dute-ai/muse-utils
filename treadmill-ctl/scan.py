#!/usr/bin/env python3
"""BLE scan: list nearby devices with names, addresses, RSSI. Read-only."""
import asyncio
import sys

from bleak import BleakScanner


async def main(duration: float = 12.0):
    print(f"Scanning for {duration:.0f}s...", flush=True)
    found = await BleakScanner.discover(timeout=duration, return_adv=True)
    if not found:
        print("No BLE devices found.")
        return
    rows = [(dev, adv.rssi) for dev, adv in found.values()]
    for dev, rssi in sorted(rows, key=lambda r: (r[1] if r[1] is not None else -999),
                            reverse=True):
        name = dev.name or "(no name)"
        print(f"{dev.address}  RSSI {rssi}  {name}", flush=True)


if __name__ == "__main__":
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 12.0
    asyncio.run(main(dur))
