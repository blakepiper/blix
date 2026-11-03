"""Exercise real notification expiry and pairing actions on an isolated X server."""
import os
from pathlib import Path
import subprocess
import sys
import time

import dbus
from Xlib import X, display


def count(kind):
    return int(subprocess.check_output(["dunstctl", "count", kind]))


def focus():
    return connection.get_input_focus().focus.id


os.environ["DISPLAY"] = ":194"
server = subprocess.Popen(["Xvfb", ":194", "-screen", "0", "800x600x24", "-nolisten", "tcp"])
daemon = None
try:
    for _ in range(100):
        if Path("/tmp/.X11-unix/X194").exists():
            break
        assert server.poll() is None, "Xvfb failed"
        time.sleep(.05)
    log = open("dunst.log", "w+")
    daemon = subprocess.Popen(["dunst", "-config", sys.argv[1], "-print"], stdout=log, stderr=log)
    bus = dbus.SessionBus()
    for _ in range(100):
        if bus.name_has_owner("org.freedesktop.Notifications"):
            break
        assert daemon.poll() is None, "Dunst failed to load the generated configuration"
        time.sleep(.05)
    else:
        raise AssertionError("Notification service did not start")
    notifications = dbus.Interface(bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications"),
                                   "org.freedesktop.Notifications")
    assert "actions" in notifications.GetCapabilities()
    connection = display.Display()
    root = connection.screen().root
    window = root.create_window(0, 0, 100, 100, 0, X.CopyFromParent)
    window.map()
    window.set_input_focus(X.RevertToParent, X.CurrentTime)
    connection.sync()
    original_focus = focus()
    icon = Path("large-icon.ppm").absolute()
    icon.write_bytes(b"P6\n128 128\n255\n" + b"\xff\x00\x00" * (128 * 128))

    # Exercise both ConnectionNotifier's transient messages and AutoConnect's
    # default-timeout messages. No Bluetooth hardware or live user bus involved.
    for message, hints in [("Connected", {"transient": True}), ("Disconnected", {"transient": True}),
                           ("Automatically connected", {})]:
        started = time.monotonic()
        notifications.Notify("blueman", 0, str(icon), "JBL Go 4", message, [], hints, -1)
        assert count("displayed") == 1
        time.sleep(.1)
        bubbles = [child for child in root.query_tree().children
                   if child.get_attributes().map_state == X.IsViewable and child.id != window.id]
        assert len(bubbles) == 1
        assert bubbles[0].get_attributes().override_redirect, "Notification became a managed window"
        assert bubbles[0].get_geometry().height < 128, "Notification rendered the large device icon"
        assert focus() == original_focus, "Status notification took keyboard focus"
        time.sleep(1.5)
        assert count("displayed") == 1, "Status notification expired too soon"
        while count("displayed") and time.monotonic() - started < 3:
            time.sleep(.05)
        assert 1.8 < time.monotonic() - started < 2.7, "Status notification did not expire after two seconds"
        assert count("history") == 0, "Status notification left history"

    pairing = notifications.Notify("blueman", 0, "blueman", "Bluetooth", "Confirm pairing",
                                   ["confirm", "Confirm", "deny", "Deny"], {}, 0)
    time.sleep(2.3)
    assert count("displayed") == 1, "Pairing request was expired by the status rule"
    notifications.CloseNotification(pairing)
    print("Connect/disconnect/reconnect expire after two seconds without focus or history; pairing stays actionable")
finally:
    if daemon:
        daemon.terminate()
        daemon.wait(timeout=3)
        log.flush()
        if sys.exc_info()[0] is not None:
            print(Path("dunst.log").read_text())
    server.terminate()
    server.wait(timeout=3)
