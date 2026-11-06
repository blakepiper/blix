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
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango, PangoCairo

PROFILES = [("performance", "Performance"), ("balanced", "Balanced"), ("power-saver", "Power Saver")]

def position(center, width):
    return max(0, min(center - 121, width - 242))


class Popup(Gtk.Window):
    def __init__(self, kind, tools, anchor):
        super().__init__(title="Blix bar slider")
        self.tools = tools
        self.kind = kind
        self.label = {"volume": "Volume", "brightness": "Brightness", "power": "Power mode"}[kind]
        self.minimum = 0 if kind == "volume" else 1
        self.accent = {"volume": "8aadf4", "brightness": "eed49f", "power": "a6da95"}[kind]
        self.popup_height = 138 if kind == "power" else 84
        self.active_choice = None
        self.choice_touched = False
        self.confirmed = False
        self.query = None
        self.next_query = 0
        self.anchor = anchor
        self.dragging = False
        self.process = None
        self.last_write = 0
        self.applied = None
        self.error = False
        try:
            if kind == "power":
                self.value = -1
            else:
                self.read_slider()
        except (OSError, ValueError, IndexError, subprocess.SubprocessError):
            self.value = self.minimum
            self.error = True
        self.applied = self.value
        self.setup_window(anchor)

    def read_slider(self):
        kind, tools = self.kind, self.tools
        args = [tools["wpctl"], "get-volume", "@DEFAULT_AUDIO_SINK@"] if kind == "volume" else [
            tools["brightnessctl"], "--class=backlight", "--machine-readable"]
        result = subprocess.run(args, capture_output=True, text=True, check=True, timeout=5)
        value = float(result.stdout.split()[1]) * 100 if kind == "volume" else float(result.stdout.split(",")[3].rstrip("%"))
        if not math.isfinite(value):
            raise ValueError("Invalid device value")
        self.value = min(100, max(self.minimum, math.floor(value + 0.5)))

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
        self.connect("destroy", lambda *_: Gtk.main_quit() if Gtk.main_level() else None)
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
        self.fixed.put(self.area, 0, 0)
        self.connect("size-allocate", self.reposition)
        self.timer = GLib.timeout_add(20, self.flush)
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
        text(19, 11, f"{self.label} unavailable" if self.error else f"{self.label} {self.value}%")
        if self.error:
            return False
        filled = round((self.value - self.minimum) * 204 / (100 - self.minimum))
        rect(19, 47, 204, 4, "444444")
        rect(19, 47, filled, 4, self.accent)
        rect(19 + filled - 5, 40, 10, 18, self.accent)
        text(19, 61, "-")
        text(213, 61, "+")
        return False

    def set_value(self, value):
        if not self.error:
            self.value = min(100, max(self.minimum, math.floor(value + 0.5)))
            self.area.queue_draw()

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
            if 0 <= index < 3:
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
        if self.kind == "volume":
            return [self.tools["wpctl"], "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", f"{self.value}%"]
        return [self.tools["brightnessctl"], "--class=backlight", "--min-value=1", "set", f"{self.value}%"]

    def flush(self):
        if self.kind == "power":
            return self.refresh_power()
        if self.process:
            code = self.process.poll()
            if code is None:
                return True
            self.process = None
            if code:
                self.error = True
                self.area.queue_draw()
        if not self.error and self.value != self.applied and time.monotonic() - self.last_write >= 0.04:
            try:
                self.process = subprocess.Popen(self.setter(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.applied = self.value
                self.last_write = time.monotonic()
            except OSError:
                self.error = True
                self.area.queue_draw()
        return True

    def confirm_choice(self):
        if 0 <= self.value < len(PROFILES):
            self.confirmed = True
            self.close()

    def refresh_power(self):
        if self.query:
            code = self.query.poll()
            if code is None:
                return True
            output, _ = self.query.communicate()
            self.query = None
            self.error = code != 0
            self.active_choice = next((index for index, (value, _) in enumerate(PROFILES) if value == output.strip()), None) if not self.error else None
            if not self.choice_touched:
                self.value = self.active_choice if self.active_choice is not None else -1
            self.area.queue_draw()
            self.next_query = time.monotonic() + 1
        if not self.query and time.monotonic() >= self.next_query:
            try:
                self.query = subprocess.Popen([self.tools["powerMode"], "power-mode"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            except OSError:
                self.error = True
                self.area.queue_draw()
                self.next_query = time.monotonic() + 1
        return True

    def finish(self):
        GLib.source_remove(self.timer)
        if self.kind == "power":
            if self.query:
                if self.query.poll() is None:
                    self.query.kill()
                self.query.communicate()
            if self.confirmed:
                # The shared backend confirms and persists the choice; failures
                # use its existing notification path. Dismissal never writes.
                subprocess.Popen([self.tools["powerMode"], "power-mode", PROFILES[self.value][0]],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return
        if self.process:
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
                return
        if not self.error and self.value != self.applied:
            subprocess.run(self.setter(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)


if __name__ == "__main__":
    tools = json.loads(Path(sys.argv[1]).read_text())
    if sys.argv[2] not in ("volume", "brightness", "power"):
        raise SystemExit("Choose volume, brightness or power")
    anchor = {key: int(os.environ[f"BLIX_PANEL_{key.upper()}"]) for key in ("center", "width", "height", "monitor")}
    popup = Popup(sys.argv[2], tools, anchor)
    Gtk.main()
    popup.finish()
