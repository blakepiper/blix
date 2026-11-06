"""Click the actual patched panel on a synthetic output and inspect its anchor."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

callback = Path('record-anchor.py').resolve()
callback.write_text("import json, os\nfrom pathlib import Path\nPath('anchor.json').write_text(json.dumps({key: value for key, value in os.environ.items() if key.startswith('BLIX_PANEL_')}))\n")
Path('panel.json').write_text(json.dumps({
    'layer': 'top', 'position': 'top', 'height': 28,
    'modules-left': ['custom/anchor'],
    'custom/anchor': {'format': 'Anchor', 'blix-popup-anchor': True,
                      'on-click': shlex.join([sys.executable, str(callback)])},
}))
Path('panel.css').write_text('* { min-height: 0; padding: 0; margin: 0; } #custom-anchor { min-width: 100px; }')
with Path('panel.log').open('w+') as log:
    process = subprocess.Popen([os.environ['PANEL_COMMAND'], '-c', 'panel.json', '-s', 'panel.css'], stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            log.flush()
            if 'Bar configured' in Path('panel.log').read_text():
                break
            assert process.poll() is None, Path('panel.log').read_text()
            time.sleep(0.05)
        else:
            raise AssertionError(Path('panel.log').read_text())
        for args in [('move', '-10000', '-10000'), ('move', '20', '14'), ('click',)]:
            subprocess.run(['wlrctl', 'pointer', *args], check=True)
            time.sleep(0.1)
        deadline = time.monotonic() + 5
        while not Path('anchor.json').exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert Path('anchor.json').exists(), Path('panel.log').read_text()
        anchor = {key: int(value) for key, value in json.loads(Path('anchor.json').read_text()).items()}
        assert anchor == {'BLIX_PANEL_CENTER': 50, 'BLIX_PANEL_WIDTH': 1280,
                          'BLIX_PANEL_HEIGHT': 28, 'BLIX_PANEL_MONITOR': 0}, anchor
    finally:
        process.terminate()
        process.wait(timeout=10)
