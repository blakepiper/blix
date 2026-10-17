"""Exercise the generated Lua configuration and native popups on an isolated X server."""

import ctypes as c
import json
import os
from pathlib import Path
import re
import select
import shlex
import subprocess as sp
import sys
import tempfile
import time


wm, config_source, xlib_path, xvfb_path, xdotool = sys.argv[1:]
scratch = Path(tempfile.mkdtemp(prefix="blix-slider-check-"))
state = scratch / "state"
state.mkdir()
for name, value in (("volume", 40), ("brightness", 70), ("power-mode", "balanced")):
    (state / name).write_text(str(value))
backend = scratch / "backend.py"
backend.write_text("""
import pathlib, sys, time
root = pathlib.Path(sys.argv[1])
name = sys.argv[2]
if len(sys.argv) == 3:
    if name == 'power-mode' and (root / 'slow-getter').exists():
        time.sleep(5)
    print((root / name).read_text() + ('' if name == 'power-mode' else '%'))
else:
    time.sleep(0.02)
    value = sys.argv[3] if name == 'power-mode' else int(sys.argv[3])
    (root / name).write_text(str(value))
    with (root / 'calls').open('a') as log:
        log.write(f'{name} {value}\\n')
""")
backend_command = " ".join(shlex.quote(str(arg)) for arg in (sys.executable, backend, state))
config = Path(config_source).read_text()
slider_colors = [int(re.search(rf'{name} = "#([0-9a-fA-F]{{6}})"', config)[1], 16)
                 for name in ("volume", "brightness", "battery")]
for pattern, command in (
    (r'"[^"\n]*/bin/oxwm-volume"', f"{backend_command} volume"),
    (r'"[^"\n]*/bin/oxwm-brightness"', f"{backend_command} brightness"),
    (r'"[^"\n]*/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ \{\}%"', f"{backend_command} volume {{}}"),
    (r'"[^"\n]*/bin/brightnessctl --class=backlight --min-value=1 set \{\}%"', f"{backend_command} brightness {{}}"),
    (r'"[^"\n]*/bin/blix-settings-apply power-mode"', f"{backend_command} power-mode"),
    (r'"[^"\n]*/bin/blix-settings-apply power-mode \{\}"', f"{backend_command} power-mode {{}}"),
    (r'"oxwm-battery"', "printf '%s' 'Bat 82%'"),
):
    config, count = re.subn(pattern, lambda _: json.dumps(command), config)
    assert count == 1, f"Expected one generated command matching {pattern}, got {count}"
config_path = scratch / "config.lua"
# Supply only a synthetic Battery/type probe; no live hardware is required.
config_path.write_text('''local real_open = io.open
io.open = function(path, mode)
  if path == "/sys/class/power_supply/test-battery/type" then
    return { read = function() return "Battery" end, close = function() end }
  end
  return real_open(path, mode)
end
''' + config)
env = os.environ.copy()
env.update(BLIX_HAS_BACKLIGHT="1", BLIX_BATTERY="test-battery", BLIX_HAS_POWER_PROFILES="1", TERMINAL="/bin/sh")
env.pop("XAUTHORITY", None)
log = (scratch / "session.log").open("w")
xvfb = sp.Popen([xvfb_path, "-displayfd", "1", "-screen", "0", "1600x800x24", "-nolisten", "tcp"], stdout=sp.PIPE, stderr=log, text=True, env=env)
manager = None
display = None


def eventually(probe, message, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if manager is not None and manager.poll() is not None:
            raise AssertionError((scratch / "session.log").read_text())
        value = probe()
        if value:
            return value
        time.sleep(0.05)
    raise AssertionError(message + "\n" + (scratch / "session.log").read_text())


def run_mouse(*args):
    sp.run([xdotool, *map(str, args)], env=env, check=True)


def popup(kind="slider"):
    result = sp.run([xdotool, "search", "--onlyvisible", "--name", f"^OXWM {kind}$"], env=env, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def geometry(window):
    output = sp.check_output([xdotool, "getwindowgeometry", "--shell", window], env=env, text=True)
    return dict((key, int(value)) for key, value in re.findall(r"^(X|Y|WIDTH|HEIGHT)=(-?\d+)$", output, re.M))


try:
    assert select.select([xvfb.stdout], [], [], 10)[0], "Xvfb did not start"
    env["DISPLAY"] = ":" + xvfb.stdout.readline().strip()
    x = c.CDLL(xlib_path)
    x.XOpenDisplay.argtypes = [c.c_char_p]
    x.XOpenDisplay.restype = c.c_void_p
    x.XDefaultRootWindow.argtypes = [c.c_void_p]
    x.XDefaultRootWindow.restype = c.c_ulong
    x.XGetImage.argtypes = [c.c_void_p, c.c_ulong, c.c_int, c.c_int, c.c_uint, c.c_uint, c.c_ulong, c.c_int]
    x.XGetImage.restype = c.c_void_p
    x.XGetPixel.argtypes = [c.c_void_p, c.c_int, c.c_int]
    x.XGetPixel.restype = c.c_ulong
    x.XDestroyImage.argtypes = [c.c_void_p]
    x.XCloseDisplay.argtypes = [c.c_void_p]
    display = x.XOpenDisplay(env["DISPLAY"].encode())
    assert display, "Could not open isolated display"
    root = x.XDefaultRootWindow(display)
    sp.run([wm, "--validate", str(config_path)], env=env, check=True)
    manager = sp.Popen([wm, "-c", str(config_path)], env=env, stdout=log, stderr=log)

    def blocks():
        capture = x.XGetImage(display, root, 0, 0, 1600, 40, c.c_ulong(-1).value, 2)
        try:
            regions = {color: [] for color in slider_colors}
            for py in range(40):
                for px in range(400, 1600):
                    color = x.XGetPixel(capture, px, py)
                    if color in regions:
                        regions[color].append(px)
            if all(regions.values()):
                return [(min(columns) + max(columns)) // 2 for columns in regions.values()]
        finally:
            x.XDestroyImage(capture)

    volume_x, brightness_x, battery_x = eventually(blocks, "Volume, brightness and battery blocks did not render")
    run_mouse("mousemove", volume_x, 10, "click", 3)
    assert popup() is None, "A non-primary click opened the slider"

    for name, button_x, minimum in (("volume", volume_x, 0), ("brightness", brightness_x, 1)):
        calls_before = (state / "calls").read_text() if (state / "calls").exists() else ""
        run_mouse("mousemove", button_x, 10, "click", 1)
        window = eventually(popup, f"{name} click did not open the native slider")
        bounds = geometry(window)
        assert bounds["WIDTH"] == 240 and bounds["Y"] > 10, "Popup must appear below the bar"
        assert ((state / "calls").read_text() if (state / "calls").exists() else "") == calls_before, "Opening the popup changed the setting"
        # Drag well past each endpoint; mouse capture must preserve and clamp it.
        run_mouse("mousemove", bounds["X"] + 120, bounds["Y"] + 48, "mousedown", 1)
        for offset in range(130, 281, 10):
            run_mouse("mousemove", bounds["X"] + offset, bounds["Y"] + 48)
        run_mouse("mouseup", 1)
        eventually(lambda: (state / name).read_text() == "100", f"{name} drag did not finish at 100%")
        run_mouse("mousemove", bounds["X"] + 120, bounds["Y"] + 48, "mousedown", 1)
        for offset in range(100, -41, -10):
            run_mouse("mousemove", bounds["X"] + offset, bounds["Y"] + 48)
        run_mouse("mouseup", 1)
        eventually(lambda: (state / name).read_text() == str(minimum), f"{name} drag exceeded its lower bound")
        run_mouse("key", "End")
        eventually(lambda: (state / name).read_text() == "100", "End did not select maximum")
        run_mouse("key", "Left")
        eventually(lambda: (state / name).read_text() == "99", "Keyboard adjustment did not decrement the value")
        if name == "volume":
            run_mouse("key", "Escape")
        else:
            run_mouse("mousemove", 20, 200, "click", 1)
        eventually(lambda: popup() is None, "Popup did not dismiss")
        values = [int(value) for kind, value in map(str.split, (state / "calls").read_text().splitlines()) if kind == name]
        assert values and all(minimum <= value <= 100 for value in values), f"{name} emitted an out-of-range command"

    def power_calls():
        return [line for line in (state / "calls").read_text().splitlines() if line.startswith("power-mode ")]

    def open_choices():
        run_mouse("mousemove", battery_x, 10, "click", 1)
        window = eventually(lambda: popup("choices"), "Bat click did not open power mode choices")
        bounds = geometry(window)
        assert bounds["WIDTH"] == 240 and bounds["HEIGHT"] == 136 and bounds["Y"] > 10
        return window, bounds

    def active_marker(window, row):
        capture = x.XGetImage(display, int(window), 22, 47 + row * 32, 1, 1, c.c_ulong(-1).value, 2)
        try:
            return x.XGetPixel(capture, 0, 0) == slider_colors[2]
        finally:
            x.XDestroyImage(capture)

    run_mouse("mousemove", battery_x, 10, "click", 3)
    assert popup("choices") is None, "A secondary battery click opened the menu"
    window, bounds = open_choices()
    eventually(lambda: active_marker(window, 1), "The active Balanced mode was not marked")
    assert not power_calls(), "Opening the menu changed power mode"
    (state / "power-mode").write_text("performance")
    eventually(lambda: active_marker(window, 0), "External mode changes were not reflected")
    assert not active_marker(window, 1), "The old active mode stayed marked"
    run_mouse("key", "End")
    assert not power_calls(), "Keyboard navigation applied an unconfirmed choice"
    run_mouse("key", "Return")
    eventually(lambda: (state / "power-mode").read_text() == "power-saver", "Enter did not apply Power Saver")
    eventually(lambda: popup("choices") is None, "The selection menu stayed open after applying")

    for row, profile in enumerate(("performance", "balanced", "power-saver")):
        window, bounds = open_choices()
        run_mouse("mousemove", bounds["X"] + 100, bounds["Y"] + 48 + row * 32, "click", 1)
        eventually(lambda: power_calls()[-1] == f"power-mode {profile}", f"Click did not apply {profile}")
        eventually(lambda: popup("choices") is None, "Click did not dismiss choices")
    before = power_calls()
    for dismiss in ("escape", "outside"):
        open_choices()
        if dismiss == "escape":
            run_mouse("key", "Home", "Escape")
        else:
            run_mouse("mousemove", 20, 200, "click", 1)
        eventually(lambda: popup("choices") is None, "Choices did not dismiss")
        assert power_calls() == before, "Dismissing choices changed power mode"

    (state / "slow-getter").touch()
    open_choices()
    started = time.monotonic()
    run_mouse("key", "Escape")
    eventually(lambda: popup("choices") is None, "Slow power getter blocked Escape", timeout=1)
    assert time.monotonic() - started < 1, "Power getter blocked the X11 event loop"

    # Dismissal must release the keyboard grab so ordinary WM bindings work again.
    run_mouse("key", "super+shift+q")
    manager.wait(timeout=8)
    assert manager.returncode == 0, "OXWM did not exit cleanly after popup dismissal"
    env["BLIX_HAS_POWER_PROFILES"] = "0"
    manager = sp.Popen([wm, "-c", str(config_path)], env=env, stdout=log, stderr=log)
    eventually(blocks, "Blocks did not return without profile support")
    run_mouse("mousemove", battery_x, 10, "click", 1)
    time.sleep(0.2)
    assert popup("choices") is None, "An unsupported host exposed power mode controls"
    run_mouse("key", "super+shift+q")
    manager.wait(timeout=8)
    assert manager.returncode == 0
    print("PASS: native sliders and power choices use the generated config; volume/brightness clamp, all power modes apply on confirmation, current mode follows external changes, slow getters stay responsive, and dismissal restores WM input without changing modes.")
finally:
    if manager is not None and manager.poll() is None:
        manager.terminate()
        manager.wait(timeout=8)
    if display:
        x.XCloseDisplay(display)
    xvfb.terminate()
    xvfb.wait(timeout=8)
    log.close()
