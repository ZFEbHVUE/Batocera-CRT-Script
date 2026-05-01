#!/usr/bin/env python3
"""
Watch the Steam Deck gamepad evdev node for a 4-button chord, then run
crt-mode-switch-combo via bash (same intent as triggerhappy BTN_* rules).

Chord: SELECT + START + L1 + L2 (BTN_SELECT, BTN_START, BTN_TL, BTN_TL2).
If any code is missing from the device caps, verify with: evtest /dev/input/eventN

Batocera's triggerhappy watches /dev/input/event*; multi-button rules can fail
on Deck due to global key state. This watcher binds one gamepad node only.

Node selection: prefers the device named exactly 'Steam Deck', then other
Deck gamepad names (e.g. 'Valve Software Steam Deck Controller'), excluding
Motion Sensors, Steam Mouse, and Virtual devices. Only nodes that expose all
chord keys are considered.

Set CRT_MODE_SWITCH_WATCHER_DEBUG=1 for per-key log lines (or create empty file
/userdata/system/crt-mode-switch-watcher.debug and restart the service; the
service wrapper enables DEBUG when that file exists).

Writes the same lines to BOTH:
  - /userdata/system/logs/crt-script-mode-switch.log (CRT Script unified log)
  - /userdata/system/logs/crt-mode-switch-watcher.log (legacy path; tail either)

Truncating only one file leaves old lines in the other. To clear both:
  truncate -s0 /userdata/system/logs/crt-script-mode-switch.log
  truncate -s0 /userdata/system/logs/crt-mode-switch-watcher.log
"""
from __future__ import annotations

import glob
import os
import subprocess
import sys
import time

try:
    from evdev import InputDevice, ecodes
except ImportError:
    sys.exit(0)

CRT_SCRIPT_LOG = "/userdata/system/logs/crt-script-mode-switch.log"
LEGACY_WATCHER_LOG = "/userdata/system/logs/crt-mode-switch-watcher.log"
_WATCHER_REV = "prod-20260501-deck-paths"
_COMBO_UD = "/userdata/system/Batocera-CRT-Script/extra/media_keys/crt-mode-switch-combo"
_COMBO_SYS = "/usr/bin/crt-mode-switch-combo"
SELECT = ecodes.BTN_SELECT
START = ecodes.BTN_START
# L1 / L2 (SDL2 jstest on Deck: 7 = L1, 9 = L2)
L1 = ecodes.BTN_TL
L2 = ecodes.BTN_TL2
CHORD_KEYS = (SELECT, START, L1, L2)
_DEBUG = os.environ.get("CRT_MODE_SWITCH_WATCHER_DEBUG") == "1"


def _log(msg: str) -> None:
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] crt-mode-switch-watcher: {msg}\n"
    for path in (CRT_SCRIPT_LOG, LEGACY_WATCHER_LOG):
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "a", encoding="utf-8", errors="replace") as f:
                f.write(line)
        except OSError:
            pass


def _deck_name_rank(name: str) -> int | None:
    """Lower rank = higher preference. None = not a Deck gamepad candidate."""
    n = (name or "").strip()
    if n == "Steam Deck":
        return 0
    if any(x in n for x in ("Motion", "Mouse", "Virtual")):
        return None
    if "Valve" in n and "Deck" in n:
        return 1
    if "Deck" in n:
        return 2
    return None


def find_steam_deck() -> InputDevice | None:
    """Open the best evdev node that exposes all CHORD_KEYS."""
    ranked: list[tuple[int, str]] = []
    for path in sorted(glob.glob("/dev/input/event*")):
        try:
            d = InputDevice(path)
        except OSError:
            continue
        rk = _deck_name_rank(d.name or "")
        if rk is None:
            try:
                d.close()
            except OSError:
                pass
            continue
        try:
            caps = set(d.capabilities().get(ecodes.EV_KEY, []))
        except (OSError, AttributeError):
            try:
                d.close()
            except OSError:
                pass
            continue
        if any(c not in caps for c in CHORD_KEYS):
            try:
                d.close()
            except OSError:
                pass
            continue
        try:
            d.close()
        except OSError:
            pass
        ranked.append((rk, path))
    if not ranked:
        return None
    ranked.sort(key=lambda x: (x[0], x[1]))
    try:
        return InputDevice(ranked[0][1])
    except OSError:
        return None


def _combo_path() -> str:
    if os.path.isfile(_COMBO_UD):
        return _COMBO_UD
    return _COMBO_SYS


def _spawn_combo() -> None:
    combo = _combo_path()
    if not os.path.isfile(combo):
        _log(f"combo script missing (checked {_COMBO_UD} and {_COMBO_SYS})")
        return
    try:
        subprocess.Popen(
            ["/bin/bash", combo],
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as e:
        _log(f"spawn failed: {e}")


def _chord_labels() -> str:
    return "SELECT+START+L1+L2 (BTN_SELECT+BTN_START+BTN_TL+BTN_TL2)"


def watch_device(dev: InputDevice) -> None:
    caps = set(dev.capabilities().get(ecodes.EV_KEY, []))
    missing = [c for c in CHORD_KEYS if c not in caps]
    if missing:
        _log(f"{dev.path} lacks required EV_KEY codes {missing}; closing")
        return

    _log(
        f"listening {dev.path} ({dev.name!r}) rev={_WATCHER_REV} chord={_chord_labels()}"
    )
    armed = True
    down = {c: False for c in CHORD_KEYS}

    for ev in dev.read_loop():
        if ev.type != ecodes.EV_KEY:
            continue
        if ev.code not in CHORD_KEYS:
            continue
        down[ev.code] = ev.value in (1, 2)
        if _DEBUG:
            if ev.value == 1:
                _log(f"keydown code={ev.code}")
            elif ev.value == 0:
                _log(f"keyup code={ev.code}")

        if all(down[c] for c in CHORD_KEYS) and armed:
            armed = False
            _log(f"chord matched ({_chord_labels()}): spawning bash {_combo_path()}")
            _spawn_combo()

        if not any(down[c] for c in CHORD_KEYS):
            armed = True


def main() -> None:
    _log(
        f"watcher main start rev={_WATCHER_REV} pid={os.getpid()} "
        f"DEBUG={_DEBUG} chord_keys={CHORD_KEYS}"
    )
    while True:
        dev = find_steam_deck()
        if dev is None:
            _log("Deck gamepad evdev not found; sleep 30s and retry")
            time.sleep(30)
            continue
        try:
            watch_device(dev)
        except OSError as e:
            _log(f"read_loop ended: {e}")
        except Exception as e:
            _log(f"unexpected error: {e!r}")
        finally:
            try:
                dev.close()
            except OSError:
                pass
        _log("device closed; sleep 2s and reopen")
        time.sleep(2)


if __name__ == "__main__":
    main()
