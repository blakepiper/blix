import os
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET

root = ET.parse('config/rc.xml').getroot()
keys = {binding.attrib['key']: binding.find('action')
        for binding in root.findall('keyboard/keybind')}
assert keys['W-S-space'].attrib['command'].endswith('/bin/blix-wayland-control-menu')
assert root.findtext('theme/icon') == 'Blix'
assert keys['W-q'].attrib['name'] == 'Close'
assert keys['W-S-f'].attrib['name'] == 'ToggleMaximize'
assert keys['W-m'].attrib['name'] == 'ToggleMaximize'
assert keys['W-S-Left'].attrib['direction'] == 'left'
assert keys['XF86Sleep'].attrib['command'].endswith('/bin/blix-suspend')
assert keys['W-S-l'].attrib['command'] == keys['XF86Sleep'].attrib['command']
assert root.findtext('desktops/popupTime') == '0'
assert root.findtext('core/decoration') == 'server'
assert [node.text for node in root.findall('desktops/names/name')] == list('123456789')
assert 'W-0' not in keys and 'W-S-0' not in keys
for number in range(1, 10):
    assert keys[f'W-{number}'].attrib['name'] == 'GoToDesktop'
    assert keys[f'W-{number}'].attrib['to'] == str(number)
    assert keys[f'W-S-{number}'].attrib['name'] == 'SendToDesktop'
    assert keys[f'W-S-{number}'].attrib['to'] == str(number)
    assert keys[f'W-S-{number}'].attrib['follow'] == 'no'
assert root.findtext("libinput/device[@category='non-touch']/naturalScroll") == 'yes'
assert root.findtext("libinput/device[@category='touchpad']/naturalScroll") == 'yes'
assert not root.findall('windowRules/windowRule/action')  # no forced tiling
with open('labwc.log', 'w+') as log:
    process = subprocess.Popen(['labwc', '-d', '-C', str(Path('config').resolve())],
                               stdout=log, stderr=log)
    try:
        for _ in range(100):
            sockets = list(Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*'))
            sockets = [socket for socket in sockets if not socket.name.endswith('.lock')]
            if sockets:
                break
            assert process.poll() is None, 'labwc exited during startup'
            time.sleep(0.1)
        assert sockets, 'labwc did not expose a Wayland socket'
        os.environ['WAYLAND_DISPLAY'] = sockets[0].name
        os.environ['GDK_BACKEND'] = 'wayland'
        subprocess.run(['python3', os.environ['SLIDER_TEST'], os.environ['SLIDER_SOURCE']], check=True)
        subprocess.run(['python3', os.environ['PANEL_TEST']], check=True)
        subprocess.run(['python3', os.environ['PANEL_PERFORMANCE_TEST']], check=True)
        subprocess.run(['python3', os.environ['TASKBAR_TEST']], check=True)
        subprocess.run(['python3', os.environ['ICON_TEST']], check=True)
        subprocess.run(['wlr-randr'], check=True)
        subprocess.run(['grim', 'headless.png'], check=True)
        assert Path('headless.png').stat().st_size > 0
        # Last: keep the synthetic compositor locked until it exits.
        subprocess.run(['python3', os.environ['LOCK_TEST']], check=True)
    finally:
        process.terminate()
        process.wait(timeout=10)
        log.seek(0)
        output = log.read()
        print(output)
    assert '[ERROR]' not in output and 'Unknown' not in output, output
