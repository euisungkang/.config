#!/usr/bin/env python3
"""Read and change Razer device settings through the OpenRazer daemon.

Usage: razer_ctl.py status
       razer_ctl.py set <dpi|brightness> <value>
"""
import json
import sys

def _device(manager):
    return manager.devices[0] if manager.devices else None


def status(manager):
    dev = _device(manager)
    if dev is None:
        return {"connected": False}

    out = {"connected": True, "name": dev.name, "serial": dev.serial}
    if dev.has("battery"):
        out["battery"] = int(dev.battery_level)
        out["charging"] = bool(dev.is_charging)
    if dev.has("dpi"):
        out["dpi"] = int(dev.dpi[0])
        out["maxDpi"] = int(dev.max_dpi)
    if dev.has("poll_rate"):
        out["pollRate"] = int(dev.poll_rate)
    if dev.has("brightness"):
        out["brightness"] = int(dev.brightness)
    return out


def apply(manager, setting, value):
    dev = _device(manager)
    if dev is None:
        raise RuntimeError("no Razer device connected")

    if setting == "dpi":
        dpi = max(100, min(int(value), int(dev.max_dpi)))
        dev.dpi = (dpi, dpi)
    elif setting == "brightness":
        dev.brightness = max(0, min(float(value), 100))
    else:
        raise ValueError(f"unknown setting: {setting}")


def _default_manager():
    from openrazer.client import DeviceManager

    return DeviceManager()


def main(argv, manager=None, manager_factory=_default_manager):
    try:
        manager = manager or manager_factory()
    except Exception:
        if argv[:1] == ["status"]:
            print(json.dumps({"connected": False}))
            return 0
        print("OpenRazer daemon unavailable", file=sys.stderr)
        return 1

    if argv[:1] == ["status"]:
        print(json.dumps(status(manager)))
        return 0
    if argv[:1] == ["set"] and len(argv) == 3:
        try:
            apply(manager, argv[1], argv[2])
        except (ValueError, RuntimeError) as e:
            print(e, file=sys.stderr)
            return 1
        return 0

    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
