"""Native Wayland counterpart of OXWM's anchored 240×82 bar slider."""
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

import cairo
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gdk, Gio, GLib, Gtk, GtkLayerShell, Pango, PangoCairo

PROFILES = [("performance", "Performance"), ("balanced", "Balanced"), ("power-saver", "Power Saver")]
POWER_SERVICE = "org.freedesktop.UPower.PowerProfiles"
POWER_PATH = "/org/freedesktop/UPower/PowerProfiles"

def position(center, width):
    return max(0, min(center - 121, width - 242))


class Popup(Gtk.Window):
    def __init__(self, kind, tools, anchor, on_close=None):
        super().__init__(title="Blix bar slider")
        self.on_close = on_close
        self.read_process = None
        self.read_timeout = None
        self.loading = kind != "power"
        self.tools = tools
        self.kind = kind
        self.label = {"volume": "Volume", "brightness": "Brightness", "monitor-brightness": "Brightness", "power": "Power mode"}[kind]
        self.minimum = 0 if kind == "volume" else 1
        self.accent = {"volume": "8aadf4", "brightness": "eed49f", "monitor-brightness": "eed49f", "power": "a6da95"}[kind]
        self.popup_height = 138 if kind == "power" else 84
        self.active_choice = None
        self.choice_touched = False
        self.confirmed = False
        self.power_proxy = None
        self.power_handlers = []
        self.cancellable = Gio.Cancellable()
        self.finished = False
        self.anchor = anchor
        self.dragging = False
        self.process = None
        self.write_timer = None
        self.child_watch = None
        self.last_write = 0
        self.applied = None
        self.error = False
        self.value = -1 if kind == "power" else self.minimum
        self.applied = self.value
        self.setup_window(anchor)
        if kind != "power":
            self.start_read()
        if kind == "power":
            # GIO loads the initial properties asynchronously and subscribes to
            # changes. An idle chooser needs no timer or helper processes.
            Gio.DBusProxy.new_for_bus(
                Gio.BusType.SYSTEM, Gio.DBusProxyFlags.DO_NOT_AUTO_START, None,
                POWER_SERVICE, POWER_PATH, POWER_SERVICE, self.cancellable,
                self.power_connected)

    def start_read(self):
        if self.kind == "monitor-brightness":
            args = [self.tools["monitorBrightness"]]
        elif self.kind == "volume":
            args = [self.tools["wpctl"], "get-volume", "@DEFAULT_AUDIO_SINK@"]
        else:
            args = [self.tools["brightnessctl"], "--class=backlight", "--machine-readable"]
        try:
            self.read_process = Gio.Subprocess.new(args, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE)
            self.read_timeout = GLib.timeout_add(5000, self.read_expired)
            self.read_process.communicate_utf8_async(None, self.cancellable, self.read_ready)
        except GLib.Error:
            self.loading = False
            self.error = True
            self.area.queue_draw()

    def read_expired(self):
        self.read_timeout = None
        if self.read_process:
            self.read_process.force_exit()
        return False

    def read_ready(self, process, result):
        if self.read_timeout:
            GLib.source_remove(self.read_timeout)
            self.read_timeout = None
        self.read_process = None
        try:
            _, output, _ = process.communicate_utf8_finish(result)
            if not process.get_successful():
                raise ValueError("Could not read device")
            if self.kind == "monitor-brightness":
                value = float(output.strip().rstrip("%"))
            elif self.kind == "volume":
                value = float(output.split()[1]) * 100
            else:
                value = float(output.split(",")[3].rstrip("%"))
            if not math.isfinite(value):
                raise ValueError("Invalid device value")
            value = min(100, max(self.minimum, math.floor(value + 0.5)))
            if not self.finished:
                self.value = self.applied = value
        except (GLib.Error, ValueError, IndexError):
            if not self.finished:
                self.error = True
        if not self.finished:
            self.loading = False
            self.area.queue_draw()

    def destroyed(self, *_):
        self.finish()
        if self.on_close:
            self.on_close(self)
        elif Gtk.main_level():
            Gtk.main_quit()

    def setup_window(self, anchor):
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "blix-bar-slider")
        display = Gdk.Display.get_default()
        monitor = display.get_monitor(anchor.get("monitor", 0))
        if monitor:
            GtkLayerShell.set_monitor(self, monitor)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_exclusive_zone(self, -1)
        self.set_app_paintable(True)
        self.set_visual(self.get_screen().get_rgba_visual())
        provider = Gtk.CssProvider()
        provider.load_from_data(b"window { background: transparent; }")
        self.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.connect("draw", self.clear_background)
        self.connect("destroy", self.destroyed)
        self.connect("key-press-event", self.key)
        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK)
        self.connect("button-press-event", self.press)
        self.connect("button-release-event", self.release)
        self.connect("motion-notify-event", self.motion)
        self.fixed = Gtk.Fixed()
        self.add(self.fixed)
        self.area = Gtk.DrawingArea()
        self.area.set_size_request(242, self.popup_height)
        self.area.connect("draw", self.draw)
        # Place the child before the first frame; mapping at (0, 0) briefly
        # painted the popup over the panel's application menu.
        self.left = position(anchor["center"], anchor["width"])
        self.top = anchor["height"] + 6
        self.fixed.put(self.area, self.left, self.top)
        self.connect("size-allocate", self.reposition)
        self.show_all()

    def reposition(self, _, allocation):
        self.left = position(self.anchor["center"], allocation.width)
        self.top = self.anchor["height"] + 6
        self.fixed.move(self.area, self.left, self.top)

    def clear_background(self, _, cr):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        return False

    def draw(self, _, cr):
        def rect(x, y, width, height, color):
            cr.set_source_rgb(*(int(color[index:index + 2], 16) / 255 for index in (0, 2, 4)))
            cr.rectangle(x, y, width, height)
            cr.fill()
        def text(x, y, value):
            layout = self.area.create_pango_layout(value)
            layout.set_font_description(Pango.FontDescription("JetBrainsMono Nerd Font 10"))
            cr.set_source_rgb(187 / 255, 187 / 255, 187 / 255)
            cr.move_to(x, y)
            PangoCairo.show_layout(cr, layout)
        rect(0, 0, 242, self.popup_height, self.accent)
        rect(1, 1, 240, self.popup_height - 2, "1a1b26")
        if self.kind == "power":
            text(19, 11, "Power mode unavailable" if self.error else self.label)
            for index, (_, title) in enumerate(PROFILES):
                y = 33 + index * 32
                if self.value == index:
                    rect(9, y, 224, 30, "444444")
                text(37, y + 7, title)
                if self.active_choice == index:
                    rect(19, y + 11, 8, 8, self.accent)
            return False
        text(19, 11, f"{self.label} …" if self.loading else f"{self.label} unavailable" if self.error else f"{self.label} {self.value}%")
        if self.error or self.loading:
            return False
        filled = round((self.value - self.minimum) * 204 / (100 - self.minimum))
        rect(19, 47, 204, 4, "444444")
        rect(19, 47, filled, 4, self.accent)
        rect(19 + filled - 5, 40, 10, 18, self.accent)
        text(19, 61, "-")
        text(213, 61, "+")
        return False

    def set_value(self, value):
        if not self.error and not self.loading:
            value = min(100, max(self.minimum, math.floor(value + 0.5)))
            if value != self.value:
                self.value = value
                self.area.queue_draw()
                self.schedule_write()

    def pointer(self, x):
        self.set_value(self.minimum + (x - self.left - 19) * (100 - self.minimum) / 204)

    def coordinates(self, event):
        widget = Gtk.get_event_widget(event) or self
        return widget.translate_coordinates(self, int(event.x), int(event.y))

    def press(self, _, event):
        pointer_x, pointer_y = self.coordinates(event)
        x, y = pointer_x - self.left, pointer_y - self.top
        if event.button == 3 or not (0 <= x < 242 and 0 <= y < self.popup_height):
            self.close()
        elif self.kind == "power":
            index = int((y - 33) // 32)
            if event.button == 1 and 0 <= index < 3:
                self.value = index
                self.confirm_choice()
        elif event.button == 1 and abs(y - 49) <= 14:
            self.dragging = True
            self.pointer(pointer_x)
        return True

    def release(self, _, event):
        if event.button == 1 and self.dragging:
            self.pointer(self.coordinates(event)[0])
            self.dragging = False
        return True

    def motion(self, _, event):
        if self.kind == "power":
            _, y = self.coordinates(event)
            index = int((y - self.top - 33) // 32)
            if 0 <= index < 3 and index != self.value:
                self.choice_touched = True
                self.value = index
                self.area.queue_draw()
            return True
        if self.dragging:
            self.pointer(self.coordinates(event)[0])
        return True

    def key(self, _, event):
        if self.kind == "power":
            if event.keyval == Gdk.KEY_Escape:
                self.close()
            elif event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter, Gdk.KEY_space):
                self.confirm_choice()
            elif event.keyval in (Gdk.KEY_Up, Gdk.KEY_Down, Gdk.KEY_Home, Gdk.KEY_End):
                self.choice_touched = True
                if event.keyval == Gdk.KEY_Home:
                    self.value = 0
                elif event.keyval == Gdk.KEY_End:
                    self.value = 2
                else:
                    self.value = min(2, max(0, self.value + (1 if event.keyval == Gdk.KEY_Down else -1)))
                self.area.queue_draw()
            return True
        if event.keyval == Gdk.KEY_Escape:
            self.close()
        elif event.keyval in (Gdk.KEY_Left, Gdk.KEY_Down):
            self.set_value(self.value - 1)
        elif event.keyval in (Gdk.KEY_Right, Gdk.KEY_Up):
            self.set_value(self.value + 1)
        elif event.keyval == Gdk.KEY_Home:
            self.set_value(self.minimum)
        elif event.keyval == Gdk.KEY_End:
            self.set_value(100)
        return True

    def setter(self):
        if self.kind == "monitor-brightness":
            return [self.tools["monitorBrightness"], str(self.value)]
        if self.kind == "volume":
            return [self.tools["wpctl"], "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", f"{self.value}%"]
        return [self.tools["brightnessctl"], "--class=backlight", "--min-value=1", "set", f"{self.value}%"]

    def schedule_write(self):
        if self.finished or self.error or self.process or self.write_timer or self.value == self.applied:
            return
        # Coalesce a drag, but never poll an idle slider or a running setter.
        delay = max(1, math.ceil((self.last_write + 0.04 - time.monotonic()) * 1000))
        self.write_timer = GLib.timeout_add(delay, self.write_value)

    def write_value(self):
        self.write_timer = None
        if not self.error and self.value != self.applied:
            try:
                self.process = subprocess.Popen(self.setter(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.applied = self.value
                self.last_write = time.monotonic()
                self.child_watch = GLib.child_watch_add(self.process.pid, self.write_finished)
            except OSError:
                self.error = True
                self.area.queue_draw()
        return False

    def write_finished(self, pid, status):
        self.child_watch = None
        # GLib has reaped the child. Tell Popen so it never waits on a reused PID.
        self.process.returncode = os.waitstatus_to_exitcode(status)
        self.error = self.process.returncode != 0
        self.process = None
        if self.error:
            self.area.queue_draw()
        elif self.finished:
            if self.value != self.applied:
                self.write_value()
        else:
            self.schedule_write()

    def confirm_choice(self):
        if not self.error and 0 <= self.value < len(PROFILES):
            self.confirmed = True
            self.close()

    def power_connected(self, _, result):
        try:
            proxy = Gio.DBusProxy.new_for_bus_finish(result)
        except GLib.Error:
            if not self.finished:
                self.error = True
                self.area.queue_draw()
            return
        if self.finished:
            return
        self.power_proxy = proxy
        self.power_handlers = [
            proxy.connect("g-properties-changed", self.refresh_power),
            proxy.connect("notify::g-name-owner", self.refresh_power),
        ]
        self.refresh_power()

    def refresh_power(self, *_):
        state = (self.active_choice, self.value, self.error)
        active = self.power_proxy.get_cached_property("ActiveProfile")
        active = active.unpack() if active is not None and self.power_proxy.get_name_owner() else None
        self.active_choice = next((index for index, (value, _) in enumerate(PROFILES) if value == active), None)
        self.error = self.active_choice is None
        if not self.choice_touched:
            self.value = self.active_choice if self.active_choice is not None else -1
        if state != (self.active_choice, self.value, self.error):
            self.area.queue_draw()

    def finish(self):
        if self.finished:
            return
        self.finished = True
        if self.read_timeout:
            GLib.source_remove(self.read_timeout)
            self.read_timeout = None
        if self.read_process:
            self.read_process.force_exit()
            self.read_process = None
        self.cancellable.cancel()
        if self.write_timer:
            GLib.source_remove(self.write_timer)
            self.write_timer = None
        if self.child_watch and not self.on_close:
            GLib.source_remove(self.child_watch)
            self.child_watch = None
        if self.kind == "power":
            if self.power_proxy:
                for handler in self.power_handlers:
                    self.power_proxy.disconnect(handler)
            if self.confirmed:
                # The shared backend confirms and persists the choice; failures
                # use its existing notification path. Dismissal never writes.
                subprocess.Popen([self.tools["powerMode"], "power-mode", PROFILES[self.value][0]],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return
        if self.on_close:
            # A resident GTK loop must never wait for a setter when dismissed.
            # The child watch finishes any final coalesced edit in order.
            if not self.process and not self.error and not self.loading and self.value != self.applied:
                self.write_value()
            return
        if self.process:
            try:
                self.error = self.process.wait(timeout=5) != 0
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
                return
        if not self.loading and not self.error and self.value != self.applied:
            subprocess.run(self.setter(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)


class PopupService:
    """One session-scoped GTK process; clicks are small native D-Bus calls."""
    name = "org.blix.BarPopups"
    path = "/org/blix/BarPopups"
    interface = """<node><interface name="org.blix.BarPopups">
      <method name="Toggle"><arg type="s" direction="in"/>
        <arg type="i" direction="in"/><arg type="i" direction="in"/>
        <arg type="i" direction="in"/><arg type="i" direction="in"/>
      </method></interface></node>"""

    def __init__(self, tools):
        self.tools = tools
        self.popup = None
        self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        info = Gio.DBusNodeInfo.new_for_xml(self.interface)
        self.registration = self.connection.register_object(self.path, info.interfaces[0], self.call, None, None)
        self.owner = Gio.bus_own_name_on_connection(self.connection, self.name,
            Gio.BusNameOwnerFlags.NONE, None, lambda *_: Gtk.main_quit())

    def closed(self, popup):
        if self.popup is popup:
            self.popup = None

    def call(self, connection, sender, path, interface, method, parameters, invocation):
        kind, center, width, height, monitor = parameters.unpack()
        if kind not in ("volume", "brightness", "monitor-brightness", "power") or width <= 0 or height < 0 or monitor < 0:
            invocation.return_dbus_error("org.blix.BarPopups.Invalid", "Invalid panel control or anchor")
            return
        previous = self.popup
        if previous:
            previous.close()
        if not previous or previous.kind != kind or previous.anchor["monitor"] != monitor:
            self.popup = Popup(kind, self.tools, dict(center=center, width=width, height=height, monitor=monitor), self.closed)
        invocation.return_value(None)


if __name__ == "__main__":
    tools = json.loads(Path(sys.argv[1]).read_text())
    if sys.argv[2] == "--daemon":
        Gtk.init([])
        service = PopupService(tools)
        Gtk.main()
    else:
        if sys.argv[2] not in ("volume", "brightness", "monitor-brightness", "power"):
            raise SystemExit("Choose volume, brightness, monitor-brightness or power")
        anchor = {key: int(os.environ[f"BLIX_PANEL_{key.upper()}"]) for key in ("center", "width", "height", "monitor")}
        popup = Popup(sys.argv[2], tools, anchor)
        Gtk.main()
        popup.finish()
