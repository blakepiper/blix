"""Keep slow DDC transactions out of OXWM's synchronous slider callback."""

import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import threading
import time


class Monitor:
    def __init__(self, ddcutil, directory):
        self.ddcutil = ddcutil
        self.directory = directory
        self.condition = threading.Condition()
        self.pending = None

    def request(self, value):
        with self.condition:
            # Replace intermediate drag positions; never queue slow DDC writes.
            self.pending = value
            self.condition.notify()

    def command(self, *args):
        return subprocess.run(
            [self.ddcutil, "--display", "1", *args],
            check=True, capture_output=True, text=True, timeout=8,
        ).stdout

    def publish(self, value):
        temporary = self.directory / "value.tmp"
        temporary.write_text(value + "\n")
        temporary.replace(self.directory / "value")

    def work(self):
        maximum = None
        next_poll = 0
        while True:
            with self.condition:
                self.condition.wait_for(
                    lambda: self.pending is not None,
                    timeout=max(0, next_poll - time.monotonic()),
                )
                target, self.pending = self.pending, None
            try:
                if target is None or maximum is None:
                    output = self.command("--terse", "getvcp", "10")
                    match = re.search(r"^VCP 10 C (\d+) (\d+)$", output, re.M)
                    if match is None or int(match[2]) <= 0:
                        raise ValueError("invalid brightness response: " + output)
                    current, maximum = map(int, match.groups())
                    self.publish(f"{current * 100 // maximum}%")
                if target is not None:
                    # Maximum is cached: no pre-read or verification round trip
                    # for every drag position. Idle polling reconciles changes
                    # made through the monitor's own controls.
                    self.command("--noverify", "setvcp", "10",
                                 str((target * maximum + 99) // 100))
                    self.publish(f"{target}%")
            except (subprocess.SubprocessError, ValueError, OSError) as error:
                print(f"monitor brightness: {error}", file=sys.stderr, flush=True)
                maximum = None
                self.publish("N/A")
            next_poll = time.monotonic() + 5


def main():
    ddcutil, *args = sys.argv[1:]
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "blix-monitor-brightness"
    address = str(directory / "socket")
    if not args:
        try:
            print((directory / "value").read_text().strip())
        except FileNotFoundError:
            print("N/A")
        return
    if args == ["serve"]:
        directory.mkdir(mode=0o700, exist_ok=True)
        Path(address).unlink(missing_ok=True)
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as server:
            server.bind(address)
            monitor = Monitor(ddcutil, directory)
            threading.Thread(target=monitor.work, daemon=True).start()
            while True:
                value = server.recv(32)
                if re.fullmatch(rb"[0-9]{1,3}", value) and 1 <= int(value) <= 100:
                    monitor.request(int(value))
    elif len(args) == 1 and re.fullmatch(r"[0-9]{1,3}", args[0]) and 1 <= int(args[0]) <= 100:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as client:
            # The main service thread only receives requests, so DDC latency
            # never holds up the slider, even while the worker is busy.
            client.settimeout(0.05)
            client.sendto(args[0].encode(), address)
    else:
        sys.exit(2)


if __name__ == "__main__":
    main()
