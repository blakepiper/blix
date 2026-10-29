"""Exercise the worker with deliberately slow DDC and rapid slider requests."""

import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time


helper, config = sys.argv[1:]
lua = Path(config).read_text()
assert lua.index('format = "Vol {}"') < lua.index('blix-monitor-brightness {}') < lua.index('format = "Ram:')


def wait_for(predicate):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.01)
    raise AssertionError("timed out")


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    environment = dict(os.environ, XDG_RUNTIME_DIR=temporary)
    log = root / "calls"
    fake = root / "ddcutil"
    fake.write_text(f'''#!{sys.executable}
import pathlib, sys, time
root = pathlib.Path({temporary!r})
with (root / "calls").open("a") as log:
    log.write(" ".join(sys.argv[1:]) + "\\n")
time.sleep(0.3)
if (root / "fail").exists():
    sys.exit(1)
if "getvcp" in sys.argv:
    print("VCP 10 C 142 200")
''')
    fake.chmod(0o755)
    command = [sys.executable, helper, str(fake)]

    def run(*args):
        return subprocess.run(command + list(args), env=environment,
                              capture_output=True, text=True, timeout=2)

    assert run().stdout == "N/A\n"
    service = subprocess.Popen(command + ["serve"], env=environment)
    directory = root / "blix-monitor-brightness"
    value = directory / "value"
    try:
        wait_for(lambda: value.exists() and value.read_text() == "71%\n")
        # A setter must return while the 300ms DDC transaction is still busy.
        assert run("20").returncode == 0
        wait_for(lambda: "setvcp" in log.read_text())
        assert value.read_text() == "71%\n"
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as client:
            for percent in range(21, 91):
                client.sendto(str(percent).encode(), str(directory / "socket"))
        wait_for(lambda: value.read_text() == "90%\n")
        calls = log.read_text().splitlines()
        assert len(calls) <= 4, calls
        assert calls[0] == "--display 1 --terse getvcp 10", calls
        assert calls[-1] == "--display 1 --noverify setvcp 10 180", calls
        assert run().stdout == "90%\n"
        # Idle reads previously ran every five seconds and stalled NVIDIA games.
        time.sleep(5.5)
        assert log.read_text().splitlines() == calls, 'Unexpected idle DDC polling'
        for invalid in ("0", "101", "-1", "oops", "1; touch bad"):
            assert run(invalid).returncode == 2
        # A failed write must not publish a falsely confirmed brightness.
        (root / "fail").touch()
        assert run("50").returncode == 0
        wait_for(lambda: value.read_text() == "N/A\n")
        (root / "fail").unlink()
        assert run("60").returncode == 0
        wait_for(lambda: value.read_text() == "60%\n")
    finally:
        service.terminate()
        service.wait(timeout=2)

print("monitor brightness: coalescing, no idle polling, nonblocking setter, scaling, failure and recovery passed")
