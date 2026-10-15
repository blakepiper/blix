#!/usr/bin/env python3
"""Temporarily keep one phone's fastboot USB connection awake.

Uses existing USB device permissions. No interfaces are claimed and no
partition commands or persistent power-policy changes are performed.
Linux USBDEVFS_FORBID_SUSPEND is scoped to the open file descriptor.
"""

import argparse
import fcntl
import os
from pathlib import Path
import signal
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--seconds", type=int, default=1800)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    stopping = False

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    deadline = time.monotonic() + args.seconds
    held_fd = None
    held_node = None
    last_error = None
    try:
        while not stopping and time.monotonic() < deadline:
            node = None
            for device in Path("/sys/bus/usb/devices").iterdir():
                try:
                    if (
                        (device / "serial").read_text().strip() == args.serial
                        and (device / "idVendor").read_text().strip() == "18d1"
                        and (device / "idProduct").read_text().strip() == "d00d"
                    ):
                        bus = int((device / "busnum").read_text())
                        number = int((device / "devnum").read_text())
                        node = f"/dev/bus/usb/{bus:03d}/{number:03d}"
                        break
                except (OSError, ValueError):
                    continue
            if node != held_node:
                if held_fd is not None:
                    os.close(held_fd)
                    print(f"Released {held_node}", flush=True)
                held_fd = None
                held_node = None
                if node is not None:
                    opened_fd = None
                    try:
                        opened_fd = os.open(node, os.O_RDWR | os.O_CLOEXEC)
                        fcntl.ioctl(opened_fd, (ord("U") << 8) | 33, 0)
                        held_fd = opened_fd
                        held_node = node
                        last_error = None
                        print(f"Holding serial {args.serial} awake at {node}", flush=True)
                    except OSError as error:
                        if opened_fd is not None:
                            os.close(opened_fd)
                        message = f"Unable to hold {node}: {error}"
                        if message != last_error:
                            print(message, flush=True)
                            last_error = message
            time.sleep(0.1)
    finally:
        if held_fd is not None:
            os.close(held_fd)
        print("USB keep-awake session finished", flush=True)


if __name__ == "__main__":
    main()
