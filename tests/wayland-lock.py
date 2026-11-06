"""Render the form and acquire a real lock only on the synthetic compositor."""
import os
import subprocess
import time

import cairo

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, Gtk

provider = Gtk.CssProvider()
css_errors = []
provider.connect("parsing-error", lambda *args: css_errors.append(str(args[-1])))
provider.load_from_path(os.environ["LOCK_STYLE"])
assert not css_errors, css_errors
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider,
                                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
builder = Gtk.Builder.new_from_file(os.environ["LOCK_LAYOUT"])
activations = []
builder.connect_signals({"window_pw_check": lambda *_: activations.append(True)})
window = Gtk.Window()
window.add(builder.get_object("window-box"))
window.fullscreen()
builder.get_object("body-revealer").set_reveal_child(True)
window.show_all()
entry = builder.get_object("input-field")
entry.grab_focus()
entry.set_text("test password")
assert not entry.get_visibility()
entry.emit("activate")
assert activations == [True], "Enter must submit the password"
assert not builder.get_object("info-box").get_visible()
assert not builder.get_object("unlock-button").get_visible()
# Authentication errors and Caps Lock warnings must remain visible.
builder.get_object("error-label").set_text("Login failed")
builder.get_object("warning-label").set_text("Caps Lock")
for _ in range(30):
    while Gtk.events_pending():
        Gtk.main_iteration_do(False)
    time.sleep(0.02)
assert builder.get_object("error-label").get_mapped()
assert builder.get_object("warning-label").get_mapped()
font = builder.get_object("identity-label").get_style_context().get_font(Gtk.StateFlags.NORMAL)
assert font.get_family() == "monospace", font.to_string()
context = window.get_style_context()
background = context.get_background_color(Gtk.StateFlags.NORMAL)
assert (background.red, background.green, background.blue) == (0, 0, 0)
subprocess.run(["grim", "lock-form.png"], check=True)
window.destroy()
while Gtk.events_pending():
    Gtk.main_iteration_do(False)

with open("locker.log", "w+") as log:
    # --daemonize returns successfully only after ext-session-lock reports locked.
    result = subprocess.run([os.environ["LOCK_COMMAND"], "--daemonize", "--config",
                             os.environ["LOCK_CONFIG"]], stdout=log, stderr=log, timeout=15)
    assert result.returncode == 0, "Locker failed to acquire the synthetic session"
    time.sleep(0.5)
    log.seek(0)
    output = log.read()
    assert not any(error in output for error in
                   ("CRITICAL", "ERROR", "Theme parsing error", "Failed")), output
    # Labwc allows screencopy of the lock surface: verify the rendered locker.
    subprocess.run(["grim", "locked.png"], check=True, timeout=5)
    image = cairo.ImageSurface.create_from_png("locked.png")
    data = image.get_data()
    width, height, stride = image.get_width(), image.get_height(), image.get_stride()
    def rgb(x, y):
        offset = y * stride + x * 4
        return tuple(data[offset:offset + 3])
    assert rgb(0, 0) == (0, 0, 0), "Locker background must be black"
    assert any(max(rgb(x, y)) > 128
               for y in range(height // 3, height * 2 // 3)
               for x in range(width // 3, width * 2 // 3)), "Password prompt must be visible"
