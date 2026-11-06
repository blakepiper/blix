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
Popup, Gtk, GLib, Gdk, Gio = (module[name] for name in ("Popup", "Gtk", "GLib", "Gdk", "Gio"))

# The test runs on a private dbus-run-session bus, never the host power daemon.
os.environ['DBUS_SYSTEM_BUS_ADDRESS'] = os.environ['DBUS_SESSION_BUS_ADDRESS']
bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
service, path = module['POWER_SERVICE'], module['POWER_PATH']
bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
              'RequestName', GLib.Variant('(su)', (service, 0)), None,
              Gio.DBusCallFlags.NONE, 5000, None)
info = Gio.DBusNodeInfo.new_for_xml(f'''<node><interface name="{service}">
  <property name="ActiveProfile" type="s" access="read"/>
</interface></node>''')
power_mode = 'balanced'
property_reads = []


def get_property(*_):
    property_reads.append(time.monotonic())
    return GLib.Variant('s', power_mode)


registration = bus.register_object(path, info.interfaces[0], None, get_property, None)


def change_profile(value):
    global power_mode
    power_mode = value
    bus.emit_signal(None, path, 'org.freedesktop.DBus.Properties', 'PropertiesChanged',
                    GLib.Variant('(sa{sv}as)', (service, {'ActiveProfile': GLib.Variant('s', value)}, [])))


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
        raise SystemExit('Power refresh must use D-Bus signals, not a subprocess')
    else:
        mode.write_text(sys.argv[-1])
        with Path({str(log)!r}).open('a') as stream:
            stream.write('power ' + sys.argv[-1] + '\\n')
    raise SystemExit(0)
if len(sys.argv) == 1:
    print('65%')
elif 'get-volume' in sys.argv:
    print('Volume: 0.40')
elif '--machine-readable' in sys.argv:
    print('test,backlight,70,70%,100')
else:
    with Path({str(log)!r}).open('a') as stream:
        stream.write(sys.argv[-1] + '\\n')
''')
    fake.chmod(0o755)
    tools = {name: str(fake) for name in ("wpctl", "brightnessctl", "powerMode")}
    for kind, initial in (("volume", 40), ("brightness", 70), ("monitor-brightness", 65)):
        tools["monitorBrightness"] = str(fake)
        suffix = "" if kind == "monitor-brightness" else "%"
        popup = Popup(kind, tools, {"center": 600, "width": 1280, "height": 28, "monitor": 0})
        assert popup.fixed.child_get_property(popup.area, 'x') == 479
        assert popup.fixed.child_get_property(popup.area, 'y') == 34
        pump()
        assert popup.value == initial
        assert popup.left == 479 and popup.top == 34, (popup.left, popup.top)
        assert popup.area.get_allocated_width() == 242
        assert popup.write_timer is None and popup.child_watch is None
        assert not log.exists(), 'An idle slider must not write device state'
        # Drive a real virtual-pointer click through GTK, including coordinate
        # translation from the drawing area's native event window.
        for args in [('move', '-10000', '-10000'), ('move', str(popup.left + 121), str(popup.top + 49)), ('click',)]:
            subprocess.run(['wlrctl', 'pointer', *args], check=True)
            pump(seconds=0.05)
        assert popup.value == (50 if kind == 'volume' else 51), popup.value
        popup.set_value(55)
        popup.set_value(76)
        pump(lambda: log.exists() and log.read_text().splitlines()[-1] == '76' + suffix, seconds=5)
        assert log.read_text().splitlines()[-1] == '76' + suffix
        popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Right))
        assert popup.value == 77
        popup.finish()
        assert log.read_text().splitlines()[-1] == '77' + suffix, 'Final value must be written before exit'
        popup.destroy()
        log.unlink()

    unavailable = directory / 'unavailable'
    unavailable.write_text(f'#!{sys.executable}\nprint("N/A")\n')
    unavailable.chmod(0o755)
    popup = Popup('monitor-brightness', {**tools, 'monitorBrightness': str(unavailable)},
                  {"center": 600, "width": 1280, "height": 28, "monitor": 0})
    assert popup.error
    popup.set_value(80)
    popup.finish()
    popup.destroy()
    assert not log.exists(), 'Unavailable monitor brightness must not write'

    # Slow setters must remain serialized while rapid edits collapse to the
    # latest value. Closing must still apply the final edit exactly once.
    slow = directory / 'slow-device'
    slow.write_text(f'''#!{sys.executable}
import fcntl, time
from pathlib import Path
with Path({str(directory / 'setter-lock')!r}).open('w') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    time.sleep(0.15)
    with Path({str(log)!r}).open('a') as stream:
        stream.write(__import__('sys').argv[-1] + '\\n')
''')
    slow.chmod(0o755)
    popup = Popup('volume', tools, {"center": 600, "width": 1280, "height": 28, "monitor": 0})
    popup.tools = {**tools, 'wpctl': str(slow)}
    popup.set_value(41)
    pump(lambda: popup.process is not None, seconds=1)
    for value in range(42, 90):
        popup.set_value(value)
    pump(lambda: popup.process is None and popup.applied == 89, seconds=5)
    assert not popup.error
    assert log.read_text().splitlines() == ['41%', '89%']
    assert popup.write_timer is None and popup.child_watch is None
    popup.set_value(90)
    popup.finish()
    assert log.read_text().splitlines() == ['41%', '89%', '90%']
    popup.destroy()
    log.unlink()
    assert module['position'](10, 1280) == 0
    assert module['position'](1279, 1280) == 1038
    anchor = {"center": 600, "width": 1280, "height": 28, "monitor": 0}
    popup = Popup('power', tools, anchor)
    pump(lambda: popup.active_choice == 1, seconds=5)
    assert popup.active_choice == popup.value == 1
    assert popup.area.get_allocated_height() == 138
    reads = len(property_reads)
    pump(seconds=1.2)
    assert len(property_reads) == reads, 'Idle power chooser must not poll D-Bus'
    assert not log.exists()
    popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Down))
    assert popup.value == 2
    popup.finish()
    popup.destroy()
    assert not log.exists(), 'Browsing or dismissing power modes must never apply a choice'

    popup = Popup('power', tools, anchor)
    pump(lambda: popup.active_choice == 1, seconds=5)
    change_profile('performance')
    pump(lambda: popup.active_choice == 0, seconds=5)
    assert popup.value == 0, 'The untouched selection should follow the daemon'
    popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Down))
    change_profile('power-saver')
    pump(lambda: popup.active_choice == 2, seconds=5)
    assert popup.value == 1, 'A refresh must preserve a user selection until confirmation'
    assert not log.exists()
    popup.confirm_choice()
    popup.finish()
    pump(lambda: log.exists(), seconds=5)
    assert mode.read_text() == 'balanced'
    assert log.read_text().splitlines() == ['power balanced']
    log.unlink()
    change_profile('unavailable')
    popup = Popup('power', tools, anchor)
    pump(seconds=0.5)
    assert popup.value == -1 and popup.active_choice is None
    popup.key(popup, SimpleNamespace(keyval=Gdk.KEY_Return))
    assert popup.get_visible(), 'Enter must not confirm an unknown profile'
    popup.finish()
    popup.destroy()
    assert not log.exists()

    # Owner loss and reappearance must be signalled, without a retry timer.
    change_profile('balanced')
    popup = Popup('power', tools, anchor)
    pump(lambda: popup.active_choice == 1, seconds=5)
    bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                  'ReleaseName', GLib.Variant('(s)', (service,)), None,
                  Gio.DBusCallFlags.NONE, 5000, None)
    pump(lambda: popup.error, seconds=5)
    assert popup.error and popup.active_choice is None
    bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                  'RequestName', GLib.Variant('(su)', (service, 0)), None,
                  Gio.DBusCallFlags.NONE, 5000, None)
    pump(lambda: popup.active_choice == 1, seconds=5)
    assert not popup.error and popup.active_choice == 1
    popup.finish()
    popup.destroy()
    # Also close while the asynchronous initial connection is pending.
    popup = Popup('power', tools, anchor)
    popup.finish()
    popup.destroy()
    pump()
    bus.unregister_object(registration)
