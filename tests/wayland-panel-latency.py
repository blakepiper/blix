"""Measure mapped popups through native IPC on the private synthetic seat."""
import os
from pathlib import Path
import shlex
import signal
import subprocess
import time

import cairo
import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib


def wait(predicate, timeout=10):
    deadline = time.monotonic() + timeout
    while not predicate():
        assert time.monotonic() < deadline, 'Popup did not change state'
        time.sleep(.005)


bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

def owned():
    result = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
        'org.freedesktop.DBus', 'NameHasOwner', GLib.Variant('(s)', ('org.blix.BarPopups',)),
        GLib.VariantType.new('(b)'), Gio.DBusCallFlags.NONE, 1000, None)
    return result.unpack()[0]


anchor = {f'BLIX_PANEL_{key}': str(value) for key, value in
          dict(CENTER=600, WIDTH=1280, HEIGHT=28, MONITOR=0).items()}
client = shlex.split(os.environ['POPUP_COMMAND'])[0]


def slider_click():
    subprocess.run([client, 'volume'], env={**os.environ, **anchor}, check=True)


def visible():
    subprocess.run(['grim', 'popup-latency.png'], check=True, stdout=subprocess.DEVNULL)
    surface = cairo.ImageSurface.create_from_png('popup-latency.png')
    # The popup accent border is at logical (479, 34) on this 1x headless output.
    offset = 34 * surface.get_stride() + 479 * 4
    return tuple(surface.get_data()[offset:offset + 3]) == (244, 173, 138)


with open('popup-service.log', 'w') as log:
    service = subprocess.Popen(shlex.split(os.environ['POPUP_COMMAND']), stdout=log, stderr=log)
    try:
        wait(owned)
        samples = []
        for _ in range(4):
            start = time.monotonic()
            slider_click()
            wait(visible, 2)
            samples.append(time.monotonic() - start)
            slider_click()
            wait(lambda: not visible(), 2)
            assert service.poll() is None
        assert max(samples[1:]) < .5, samples
        print('Slider click-to-frame ms:', [round(value * 1000) for value in samples])
    finally:
        service.terminate()
        service.wait(timeout=10)
wait(lambda: not owned())

logfile = Path('resident-menu.log')
with logfile.open('w') as log:
    menu = subprocess.Popen([*shlex.split(os.environ['MENU_COMMAND']), '-debug'], stdout=log, stderr=log)
    try:
        wait(lambda: 'UI created in' in logfile.read_text())
        assert 'Resident menu mapped' not in logfile.read_text(), 'Menu flashed at login'
        samples = []
        for index in range(4):
            start = time.monotonic()
            menu.send_signal(signal.SIGUSR1)
            wait(lambda: logfile.read_text().count('Resident menu mapped') == index + 1, 2)
            samples.append(time.monotonic() - start)
            menu.send_signal(signal.SIGUSR1)
            wait(lambda: logfile.read_text().count('Resident menu hidden') == index + 1, 2)
            assert menu.poll() is None
        assert logfile.read_text().count('UI created in') == 1, 'Menu rebuilt between clicks'
        assert max(samples[1:]) < .5, samples
        print('Resident menu signal-to-map ms:', [round(value * 1000) for value in samples])
    finally:
        menu.terminate()
        menu.wait(timeout=10)
