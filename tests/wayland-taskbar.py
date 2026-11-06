"""Restore a genuinely minimized client through the generated taskbar action."""
import json
import os
from pathlib import Path
import subprocess
import time

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk


def pump(seconds=0.3):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        time.sleep(0.01)


def minimized():
    return subprocess.run(['wlrctl', 'toplevel', 'find',
                           'title:Minimize and restore test', 'state:minimized'],
                          capture_output=True).returncode == 0


config = json.loads(Path(os.environ['PANEL_CONFIG']).read_text())
assert 'wlr/taskbar' in config['modules-left']
# Isolate the taskbar so the only client's button has a known pointer position.
config['modules-left'] = ['wlr/taskbar']
config['modules-right'] = []
Path('taskbar.json').write_text(json.dumps(config))
with Path('taskbar.log').open('w+') as log:
    panel = subprocess.Popen([os.environ['PANEL_COMMAND'], '-c', 'taskbar.json',
                              '-s', os.environ['PANEL_STYLE']], stdout=log, stderr=log)
    window = Gtk.Window(title='Minimize and restore test')
    window.set_default_size(320, 200)
    window.set_icon_name('utilities-terminal')
    try:
        deadline = time.monotonic() + 10
        while 'Bar configured' not in Path('taskbar.log').read_text():
            assert panel.poll() is None, Path('taskbar.log').read_text()
            assert time.monotonic() < deadline, Path('taskbar.log').read_text()
            pump(0.05)
        window.show_all()
        pump()
        window.iconify()
        pump()
        assert minimized()
        for args in [('move', '-10000', '-10000'), ('move', '24', '14'), ('click',)]:
            subprocess.run(['wlrctl', 'pointer', *args], check=True)
            pump()
        assert not minimized(), 'Taskbar failed to restore minimized window'
        subprocess.run(['wlrctl', 'pointer', 'click'], check=True)
        pump()
        assert minimized(), 'Taskbar failed to minimize active window'
        assert '[error]' not in Path('taskbar.log').read_text().lower(), Path('taskbar.log').read_text()
        print('Taskbar restored minimized client and minimized active client via real pointer clicks')
    finally:
        window.destroy()
        pump(0.1)
        panel.terminate()
        panel.wait(timeout=10)
