"""Check that slow status commands leave WM input responsive on an isolated X server."""

import json
import os
from pathlib import Path
import select
import shlex
import signal
import subprocess as sp
import sys
import tempfile
import time


wm, xvfb_path, xdotool = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix="blix-bar-async-") as directory:
    root = Path(directory)
    started = root / "started"
    finished = root / "finished"
    backend = root / "backend.py"
    backend.write_text("""
import os, pathlib, sys, time
started, finished = map(pathlib.Path, sys.argv[1:])
started.write_text(str(os.getpid()))
time.sleep(2)
finished.touch()
print('42% (muted)')
""")
    command = shlex.join([sys.executable, str(backend), str(started), str(finished)])
    config = root / "config.lua"
    config.write_text("""
oxwm.set_terminal('/bin/sh')
oxwm.set_modkey('Mod4')
oxwm.set_tags({'1', '2'})
oxwm.bar.set_font('DejaVu Sans:size=10')
oxwm.bar.set_blocks({oxwm.bar.block.shell({
  format = 'Vol {}', command = %s, interval = 60,
})})
oxwm.key.bind({'Mod4', 'Shift'}, 'Q', oxwm.quit())
""" % json.dumps(command))
    env = os.environ.copy()
    env.pop("XAUTHORITY", None)
    with (root / "session.log").open("w") as log:
        xvfb = sp.Popen([xvfb_path, "-displayfd", "1", "-screen", "0", "800x600x24", "-nolisten", "tcp"],
                        stdout=sp.PIPE, stderr=log, text=True, env=env)
        manager = None
        try:
            assert select.select([xvfb.stdout], [], [], 10)[0], "Xvfb did not start"
            env["DISPLAY"] = ":" + xvfb.stdout.readline().strip()
            manager = sp.Popen([wm, "-c", str(config)], env=env, stdout=log, stderr=log)
            deadline = time.monotonic() + 8
            while not started.exists() and time.monotonic() < deadline:
                assert manager.poll() is None, (root / "session.log").read_text()
                time.sleep(0.01)
            assert started.exists(), "The collector did not start"
            assert not finished.exists(), "The slow collector already completed"
            beginning = time.monotonic()
            sp.run([xdotool, "key", "super+shift+q"], env=env, check=True, timeout=4)
            manager.wait(timeout=0.5)
            response = time.monotonic() - beginning
            assert manager.returncode == 0, "WM did not exit cleanly with a collector running"
            assert not finished.exists(), "Teardown left the collector running"
            print(f"PASS: native quit shortcut handled in {response:.3f}s during a two-second collector; clean exit cancels pending work.")
        finally:
            if manager is not None and manager.poll() is None:
                manager.terminate()
                manager.wait(timeout=4)
            if started.exists():
                pid = int(started.read_text())
                try:
                    if str(backend).encode() in Path(f"/proc/{pid}/cmdline").read_bytes():
                        os.kill(pid, signal.SIGKILL)
                except (FileNotFoundError, ProcessLookupError):
                    pass
            xvfb.terminate()
            xvfb.wait(timeout=4)
