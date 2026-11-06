"""Exercise native slider rendering, anchoring and writes on the synthetic seat."""
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace

module = runpy.run_path(sys.argv[1], run_name="slider_test")
Popup, Gtk, GLib, Gdk = (module[name] for name in ("Popup", "Gtk", "GLib", "Gdk"))


def pump(until=lambda: False, seconds=0.2):
    deadline = time.monotonic() + seconds
    context = GLib.MainContext.default()
    while time.monotonic() < deadline:
        while context.pending():
            context.iteration(False)
        if until():
            return
        time.sleep(0.01)


with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)
    log = directory / "writes"
    mode = directory / "power-mode"
    mode.write_text('balanced')
    fake = directory / "device"
    fake.write_text(f'''#!{sys.executable}
import sys
from pathlib import Path
if 'power-mode' in sys.argv:
    mode = Path({str(mode)!r})
    if len(sys.argv) == 2:
        print(mode.read_text())
    else:
        mode.write_text(sys.argv[-1])
        with Path({str(log)!r}).open('a') as stream:
            stream.write('power ' + sys.argv[-1] + '\\n')
    raise SystemExit(0)
if 'get-volume' in sys.argv:
    print('Volume: 0.40')
elif '--machine-readable' in sys.argv:
    print('test,backlight,70,70%,100')
else:
    with Path({str(log)!r}).open('a') as stream:
        stream.write(sys.argv[-1] + '\\n')
''')
    fake.chmod(0o755)
    tools = {name: str(fake) for name in ("wpctl", "brightnessctl", "powerMode")}
    for kind, initial in (("volume", 40), ("brightness", 70)):
        popup = Popup(kind, tools, {"center": 600, "width": 1280, "height": 28, "monitor": 0})
        assert popup.fixed.child_get_property(popup.area, 'x') == 479
        assert popup.fixed.child_get_property(popup.area, 'y') == 34
        pump()
        assert popup.value == initial
        assert popup.left == 479 and popup.top == 34, (popup.left, popup.top)
        assert popup.area.get_allocated_width() == 242
        # Drive a real virtual-pointer click through GTK, including coordinate
        # translation from the drawing area's native event window.
        for args in [('move', '-10000', '-10000'), ('move', str(popup.left + 121), str(popup.top + 49)), ('click',)]:
            subprocess.run(['wlrctl', 'pointer', *args], check=True)
            pump(seconds=0.05)
        assert popup.value == (50 if kind == 'volume' else 51), popup.value
        popup.set_value(55)
        popup.set_value(76)
        pump(lambda: log.exists() and log.read_text().splitlines()[-1] == '76%', seconds=5)
        assert log.read_text().splitlines()[-1] == '76%'
        popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Right))
        assert popup.value == 77
        popup.finish()
        assert log.read_text().splitlines()[-1] == '77%', 'Final value must be written before exit'
        popup.destroy()
        log.unlink()
    assert module['position'](10, 1280) == 0
    assert module['position'](1279, 1280) == 1038
    anchor = {"center": 600, "width": 1280, "height": 28, "monitor": 0}
    popup = Popup('power', tools, anchor)
    pump(lambda: popup.active_choice == 1, seconds=5)
    assert popup.active_choice == popup.value == 1
    assert popup.area.get_allocated_height() == 138
    popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Down))
    assert popup.value == 2
    popup.finish()
    popup.destroy()
    assert not log.exists(), 'Browsing or dismissing power modes must never apply a choice'

    popup = Popup('power', tools, anchor)
    pump(lambda: popup.active_choice == 1, seconds=5)
    mode.write_text('performance')
    pump(lambda: popup.active_choice == 0, seconds=5)
    assert popup.value == 0, 'The untouched selection should follow the daemon'
    popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Down))
    mode.write_text('power-saver')
    pump(lambda: popup.active_choice == 2, seconds=5)
    assert popup.value == 1, 'A refresh must preserve a user selection until confirmation'
    assert not log.exists()
    popup.confirm_choice()
    popup.finish()
    pump(lambda: log.exists(), seconds=5)
    assert mode.read_text() == 'balanced'
    assert log.read_text().splitlines() == ['power balanced']
    log.unlink()
    mode.write_text('unavailable')
    popup = Popup('power', tools, anchor)
    pump(seconds=0.5)
    assert popup.value == -1 and popup.active_choice is None
    popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Return))
    assert popup.get_visible(), 'Enter must not confirm an unknown profile'
    popup.finish()
    popup.destroy()
    assert not log.exists()
