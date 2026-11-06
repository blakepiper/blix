"""Check actual telemetry syscalls and fullscreen occlusion on a synthetic seat."""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

import cairo
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

config = json.loads(Path(os.environ['PANEL_CONFIG']).read_text())
assert config['image#logo']['interval'] == 'once'
assert config['cpu_usage']['interval'] == 10
assert config['battery']['interval'] >= 60
assert config['backlight']['interval'] >= 60
assert 'cpu' not in config['modules-right']
assert not any(name.startswith('custom/') for name in config['modules-right'])
# Exercise the generated configuration, with hardware-independent modules and a
# shorter sampling period so multiple real updates can be observed quickly.
config['modules-right'] = ['cpu_usage', 'memory', 'clock']
config['cpu_usage']['interval'] = 1
Path('telemetry.json').write_text(json.dumps(config))


def pump(seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        time.sleep(0.01)


with Path('telemetry.log').open('w+') as log:
    process = subprocess.Popen([
        'strace', '-f', '-ttt', '-e', 'trace=openat,execve', '-o', 'telemetry.trace',
        os.environ['PANEL_COMMAND'], '-c', 'telemetry.json', '-s', os.environ['PANEL_STYLE'],
    ], stdout=log, stderr=log, start_new_session=True)
    try:
        deadline = time.monotonic() + 10
        while 'Bar configured' not in Path('telemetry.log').read_text():
            assert process.poll() is None, Path('telemetry.log').read_text()
            assert time.monotonic() < deadline, Path('telemetry.log').read_text()
            time.sleep(0.05)
        # Exclude library/font initialization. No external commands or hardware
        # frequency probes should be necessary once telemetry is running.
        pump(1)
        start = time.time()
        pump(2.2)
        lines = []
        for line in Path('telemetry.trace').read_text().splitlines():
            match = re.search(r'\s(\d{10}\.\d+)\s', line)
            if match and float(match[1]) >= start:
                lines.append(line)
        stat_reads = sum('"/proc/stat"' in line for line in lines)
        assert stat_reads >= 2, 'CPU label did not actually sample usage'
        assert not any('"/proc/cpuinfo"' in line or '/cpufreq/' in line for line in lines), lines
        assert not any('execve(' in line for line in lines), lines
        assert '[error]' not in Path('telemetry.log').read_text().lower()

        # A fullscreen game must cover the top-layer panel. Do not introduce an
        # overlay bar that forces composition above fullscreen applications.
        window = Gtk.Window()
        window.connect('draw', lambda _, cr: (cr.set_source_rgb(1, 0, 0), cr.paint(), True)[-1])
        window.fullscreen()
        window.show_all()
        pump(0.5)
        subprocess.run(['grim', 'fullscreen.png'], check=True)
        image = cairo.ImageSurface.create_from_png('fullscreen.png')
        offset = 4 * (image.get_width() // 2)
        assert tuple(image.get_data()[offset:offset + 3]) == (0, 0, 255), 'Panel covers fullscreen content'
        window.destroy()
        pump(0.1)
        print(f'Telemetry: {stat_reads} usage samples, zero frequency probes or helper launches; fullscreen occlusion passed')
    finally:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)
