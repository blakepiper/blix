"""Verify real labwc layout after resizing/scaling two synthetic outputs."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('outputs', sys.argv[1])
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    runtime = root / 'runtime'
    runtime.mkdir(mode=0o700)
    config = root / 'config'
    config.mkdir()
    for name in ('autostart', 'shutdown', 'environment'):
        (config / name).touch()
    (config / 'rc.xml').write_text('<labwc_config />')
    env = {**os.environ, 'XDG_RUNTIME_DIR': str(runtime), 'WLR_BACKENDS': 'headless',
           'WLR_RENDERER': 'pixman', 'WLR_HEADLESS_OUTPUTS': '2'}
    for name in ('DISPLAY', 'WAYLAND_DISPLAY'):
        env.pop(name, None)
    with open(root / 'log', 'w') as log:
        process = subprocess.Popen(['labwc', '-C', str(config)], env=env, stdout=log, stderr=log)
        try:
            for _ in range(100):
                sockets = [p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')]
                if sockets:
                    break
                assert process.poll() is None
                time.sleep(.1)
            assert sockets
            os.environ.update(XDG_RUNTIME_DIR=str(runtime), WAYLAND_DISPLAY=sockets[0].name)
            outputs = json.loads(subprocess.check_output(['wlr-randr', '--json'], text=True))
            names = [o['name'] for o in outputs]
            assert len(names) == 2
            manager.apply(dict(primary=names[0], external=[names[1]], layout='mirror',
                               mode='1920x1080', rate=None, scales={names[0]: 1.25}))
            outputs = json.loads(subprocess.check_output(['wlr-randr', '--json'], text=True))
            assert all(o['position'] == {'x': 0, 'y': 0} and o['scale'] == 1.25 for o in outputs), outputs
        finally:
            process.terminate()
            process.wait(timeout=10)
print('PASS: isolated two-output labwc mirroring and 125% scale')
