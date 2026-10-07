import array
from concurrent.futures import ThreadPoolExecutor
import json
import math
from pathlib import Path
import re
import subprocess
import threading
import time

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, Gio, GLib, Gtk

import core
from core import SettingsError
from demo import Demo, DemoPreferences, DemoRadio


PAGES = [
    ("display", "Display", "video-display-symbolic", "Monitors, arrangement, resolution, refresh rate and brightness", "screen monitor resolution refresh rotation scale brightness"),
    ("audio", "Audio", "audio-volume-high-symbolic", "Speakers, headphones and microphones", "sound volume microphone mic input output mute"),
    ("bluetooth", "Bluetooth", "bluetooth-symbolic", "Pair and manage nearby devices", "wireless pair headset headphones keyboard device"),
    ("network", "Networking", "network-wireless-symbolic", "Wi-Fi, Ethernet and saved connections", "wifi wi-fi internet ethernet connection password vpn"),
    ("power", "Power", "battery-symbolic", "Battery status, display timeout and session controls", "battery charging sleep suspend lock screen off idle"),
    ("input", "Input", "input-touchpad-symbolic", "Pointing devices and keyboard repeat", "mouse touchpad keyboard tapping scrolling speed repeat"),
    ("shortcuts", "Shortcuts", "preferences-desktop-keyboard-shortcuts-symbolic", "A quick reference for your OXWM keyboard shortcuts", "key binding super shortcut"),
    ("about", "About", "computer-symbolic", "Your device and the Blix desktop", "system version cpu processor memory storage kernel"),
]


def label(text, style=None, wrap=False):
    widget = Gtk.Label(label=text, xalign=0)
    widget.set_line_wrap(wrap)
    if style:
        widget.get_style_context().add_class(style)
    return widget


def box(vertical=True, spacing=12):
    return Gtk.Box(orientation=Gtk.Orientation.VERTICAL if vertical else Gtk.Orientation.HORIZONTAL, spacing=spacing)


def button(text, callback, suggested=False):
    widget = Gtk.Button(label=text)
    widget.connect("clicked", lambda *_: callback())
    if suggested:
        widget.get_style_context().add_class("suggested-action")
    return widget


def combo(entries, current=None):
    widget = Gtk.ComboBoxText()
    widget.entries = []
    update_combo(widget, entries, current)
    return widget


def update_combo(widget, entries, current=None):
    entries = [(str(key), str(value)) for key, value in entries]
    if widget.entries != entries:
        widget.remove_all()
        for key, value in entries:
            widget.append(key, value)
        widget.entries = entries
    if current is not None:
        widget.set_active_id(str(current))
    elif widget.get_active() < 0 and entries:
        widget.set_active(0)


def spin(value, minimum, maximum, step=1):
    widget = Gtk.SpinButton.new_with_range(minimum, maximum, step)
    widget.set_value(value)
    return widget


class Window(Gtk.ApplicationWindow):
    def __init__(self, application, demo=False):
        super().__init__(application=application, title="Blix Settings")
        self.set_default_size(1060, 760)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_icon_name("preferences-system")
        self.demo = Demo() if demo else None
        self.preferences = DemoPreferences() if demo else core.Preferences()
        self.defaults = self.demo.defaults if demo else core.defaults()
        self.executor = ThreadPoolExecutor(max_workers=3, thread_name_prefix="blix-settings")
        self.closed = False
        self.syncing = False
        self.refreshing = False
        self.page = None
        self.dirty_display = False
        self.preview = None
        self.meter = None
        self.radio_errors = {}
        self.last_models = {}
        self.pages = {}
        self.controls = {}
        self.pending_sliders = {}
        self.dialogs = []
        self.connect("delete-event", self.close_window)
        self.connect("key-press-event", self.key_pressed)
        provider = Gtk.CssProvider()
        provider.load_from_path(str(Path(__file__).with_name("style.css")))
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme", True)
        self.build_shell()
        self.initialize_radios()
        for name, title, _, subtitle, _ in PAGES:
            content = box(spacing=18)
            for method in (content.set_margin_top, content.set_margin_bottom, content.set_margin_start, content.set_margin_end):
                method(24)
            content.pack_start(label(title, "page-title"), False, False, 0)
            content.pack_start(label(subtitle, "subtitle", True), False, False, 0)
            body = box(spacing=16)
            content.pack_start(body, False, False, 0)
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.add(content)
            if name == "display":
                display_page = box(spacing=0)
                display_page.pack_start(scroll, True, True, 0)
                self.display_footer = box(spacing=8)
                self.display_footer.set_border_width(16)
                display_page.pack_end(self.display_footer, False, False, 0)
                self.stack.add_named(display_page, name)
            else:
                self.stack.add_named(scroll, name)
            self.pages[name] = body
        self.build_audio()
        self.build_power()
        self.build_shortcuts()
        self.build_about()
        self.show_all()
        self.sidebar.select_row(self.sidebar.get_row_at_index(0))
        self.poll = GLib.timeout_add_seconds(3, self.refresh)

    def build_shell(self):
        root = box(spacing=0)
        self.add(root)
        main = box(False, 0)
        root.pack_start(main, True, True, 0)
        sidebar = box(spacing=18)
        sidebar.set_size_request(220, -1)
        sidebar.get_style_context().add_class("sidebar")
        brand = label("BLIX", "brand")
        brand.set_margin_start(22)
        brand.set_margin_top(26)
        sidebar.pack_start(brand, False, False, 0)
        caption = label("Settings" + (" · Preview" if self.demo else ""), "dim")
        caption.set_margin_start(22)
        sidebar.pack_start(caption, False, False, 0)
        self.search = Gtk.SearchEntry(placeholder_text="Find a setting…")
        self.search.set_margin_start(12)
        self.search.set_margin_end(12)
        self.search.connect("search-changed", self.search_changed)
        sidebar.pack_start(self.search, False, False, 0)
        self.sidebar = Gtk.ListBox()
        self.sidebar.set_selection_mode(Gtk.SelectionMode.SINGLE)
        for name, title, icon, _, keywords in PAGES:
            row = Gtk.ListBoxRow()
            row.page_name, row.keywords = name, (title + " " + keywords).lower()
            content = box(False, 12)
            content.pack_start(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR), False, False, 0)
            content.pack_start(label(title), True, True, 0)
            row.add(content)
            self.sidebar.add(row)
        self.sidebar.connect("row-selected", self.page_selected)
        sidebar.pack_start(self.sidebar, False, False, 0)
        footer = label("Super + S  ·  Open settings", "dim", True)
        footer.set_margin_start(18)
        footer.set_margin_bottom(18)
        sidebar.pack_end(footer, False, False, 0)
        main.pack_start(sidebar, False, False, 0)
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.NONE)
        main.pack_start(self.stack, True, True, 0)
        self.status = Gtk.Revealer()
        status_box = box(False, 12)
        status_box.get_style_context().add_class("status")
        self.status_box = status_box
        self.status_label = label("", wrap=True)
        status_box.pack_start(self.status_label, True, True, 0)
        status_box.pack_end(button("Dismiss", lambda: self.status.set_reveal_child(False)), False, False, 0)
        self.status.add(status_box)
        root.pack_end(self.status, False, False, 0)

    def initialize_radios(self):
        if self.demo:
            self.network = DemoRadio(self.demo, "network")
            self.bluetooth = DemoRadio(self.demo, "bluetooth")
            return
        from radios import Network, Bluetooth
        try:
            self.network = Network(self.radio_changed)
        except Exception as error:
            self.network = None
            self.radio_errors["network"] = str(error)
        if self.defaults.get("capabilities", {}).get("hasBluetooth", True):
            try:
                self.bluetooth = Bluetooth(self.radio_changed, self.prompt, self.notify)
            except Exception as error:
                self.bluetooth = None
                self.radio_errors["bluetooth"] = str(error)
        else:
            self.bluetooth = None
            self.radio_errors["bluetooth"] = "Bluetooth is not enabled on this device."

    def command(self, name, *args):
        return self.demo.command(name, *args) if self.demo else core.command(name, *args)

    def advanced_connections(self):
        if self.demo:
            self.demo.command("connectionEditor")
        else:
            self.attempt(lambda: subprocess.Popen([core.TOOLS["connectionEditor"]]))

    def run(self, function, done=None, failed=None):
        future = self.executor.submit(function)
        def complete(_):
            def update():
                if self.closed:
                    if not future.cancelled() and future.exception() is None:
                        result = future.result()
                        if isinstance(result, subprocess.Popen) and result.stdin:
                            result.stdin.close()
                    return False
                try:
                    result = future.result()
                    if done:
                        done(result)
                except Exception as error:
                    failed(error) if failed else self.notify(str(error), True)
                finally:
                    self.refreshing = False
                return False
            GLib.idle_add(update)
        future.add_done_callback(complete)

    def notify(self, text, error=False):
        if self.closed:
            return
        context = self.status_box.get_style_context()
        context.add_class("error") if error else context.remove_class("error")
        self.status_label.set_text(text)
        self.status.set_reveal_child(True)

    def prompt(self, title, message, text_entry, callback, secret=False):
        dialog = Gtk.Dialog(title=title, transient_for=self, modal=True)
        dialog.set_default_size(420, -1)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Connect" if secret else "Confirm", Gtk.ResponseType.OK)
        dialog.set_default_response(Gtk.ResponseType.OK)
        content = dialog.get_content_area()
        content.set_spacing(14)
        content.set_border_width(20)
        content.pack_start(label(message, wrap=True), False, False, 0)
        entry = None
        if text_entry:
            entry = Gtk.Entry()
            entry.set_visibility(not secret)
            entry.set_input_purpose(Gtk.InputPurpose.PASSWORD if secret else Gtk.InputPurpose.FREE_FORM)
            entry.set_activates_default(True)
            content.pack_start(entry, False, False, 0)
        answered = False
        def response(_, response_id):
            nonlocal answered
            if answered:
                return
            answered = True
            value = (entry.get_text() if entry else True) if response_id == Gtk.ResponseType.OK else None
            if entry:
                entry.set_text("")
            dialog.destroy()
            self.dialogs.remove(dialog)
            callback(value)
        dialog.connect("response", response)
        self.dialogs.append(dialog)
        dialog.show_all()
        if entry:
            entry.grab_focus()
        return lambda: dialog.response(Gtk.ResponseType.CANCEL)

    def attempt(self, function):
        try:
            function()
        except Exception as error:
            self.notify(str(error), True)

    def radio_done(self, error):
        if error:
            self.notify(error, True)
        self.last_models.pop(self.page, None)
        self.refresh()

    def radio_changed(self):
        if not self.closed and self.page in ("network", "bluetooth") and not self.dialogs:
            def once():
                self.refresh()
                return False
            GLib.idle_add(once)

    def search_changed(self, *_):
        query = self.search.get_text().strip().lower()
        matches = []
        for row in self.sidebar.get_children():
            visible = not query or all(word in row.keywords for word in query.split())
            row.set_visible(visible)
            if visible:
                matches.append(row)
        if matches and self.sidebar.get_selected_row() not in matches:
            self.sidebar.select_row(matches[0])

    def page_selected(self, _, row):
        if not row:
            return
        if self.page == "bluetooth" and self.bluetooth:
            self.bluetooth.stop_scan()
        if self.page == "audio":
            self.stop_meter()
        self.page = row.page_name
        self.stack.set_visible_child_name(self.page)
        self.refresh()

    def key_pressed(self, _, event):
        control = event.state & Gdk.ModifierType.CONTROL_MASK
        if control and event.keyval == Gdk.KEY_f:
            self.search.grab_focus()
            return True
        if event.keyval == Gdk.KEY_Escape and not self.dialogs:
            if self.search.get_text():
                self.search.set_text("")
            else:
                self.close()
            return True
        if event.keyval == Gdk.KEY_F5:
            self.last_models.pop(self.page, None)
            self.refresh()
            return True
        return False

    def clear(self, page):
        body = self.pages[page]
        for child in body.get_children():
            body.remove(child)
        return body

    def card(self, body, title=None):
        content = box(spacing=14)
        content.get_style_context().add_class("card")
        if title:
            content.pack_start(label(title, "section-title"), False, False, 0)
        body.pack_start(content, False, False, 0)
        return content

    def row(self, parent, title, widget, description=None):
        content = box(False, 16)
        text = box(spacing=4)
        text.pack_start(label(title), False, False, 0)
        if description:
            text.pack_start(label(description, "dim", True), False, False, 0)
        content.pack_start(text, True, True, 0)
        content.pack_end(widget, False, False, 0)
        parent.pack_start(content, False, False, 0)

    def refresh(self):
        if self.closed:
            return False
        if not self.page or self.refreshing or self.dialogs or self.preview:
            return True
        page = self.page
        if page in ("display", "input"):
            if page == "display" and self.dirty_display:
                return True
            self.refreshing = True
            function = (lambda: self.demo.snapshot(page)) if self.demo else (core.outputs if page == "display" else core.input_devices)
            self.run(function, lambda value: self.build_devices(page, value))
        elif page == "audio":
            self.refreshing = True
            self.run(lambda: self.demo.snapshot("audio") if self.demo else core.audio_state(), self.update_audio)
        elif page in ("network", "bluetooth"):
            radio = self.network if page == "network" else self.bluetooth
            if not radio:
                body = self.clear(page)
                body.pack_start(label(self.radio_errors.get(page, "This service is unavailable."), wrap=True), False, False, 0)
                body.show_all()
            else:
                self.attempt(lambda: self.build_radio(page, radio.snapshot()))
        elif page == "power":
            self.refreshing = True
            self.run(lambda: [{"name": "Battery", "capacity": "82", "status": "Discharging", "charge_limit": "80"}]
                     if self.demo else core.batteries(), self.update_batteries)
        return True

    def build_devices(self, page, value):
        model = json.dumps(value, sort_keys=True)
        if self.last_models.get(page) == model:
            return
        self.last_models[page] = model
        if page == "display":
            self.build_display(value)
        else:
            self.build_input(value)

    def build_display(self, available):
        body = self.clear("display")
        for child in self.display_footer.get_children():
            self.display_footer.remove(child)
        self.available_outputs = available
        connected = [item for item in available if item["connected"] and item["modes"]]
        if not connected:
            body.pack_start(label("No connected displays were found."), False, False, 0)
            body.show_all()
            return
        overview = box(False, 12)
        for item in connected:
            monitor = label(item["name"] + (" · Primary" if item["primary"] else "") + "\n" + (item["mode"] or "Disabled"), "monitor")
            overview.pack_start(monitor, True, True, 0)
        body.pack_start(overview, False, False, 0)
        settings = self.card(body)
        remembered = self.preferences.read().get("display")
        current_layout = remembered.get("layout") if remembered else ("mirror" if len(connected) > 1 and
            all(item["x"] == connected[0]["x"] and item["y"] == connected[0]["y"] for item in connected) else "extend")
        self.display_layout = combo([("extend", "Extend"), ("mirror", "Mirror")], current_layout)
        self.display_layout.connect("changed", lambda *_: self.display_changed())
        self.row(settings, "Layout", self.display_layout, "Mirroring shares a resolution; each display keeps its own refresh rate.")
        primary = next((item["name"] for item in connected if item["primary"]), connected[0]["name"])
        self.display_primary = combo([(item["name"], item["name"]) for item in connected], primary)
        self.display_primary.connect("changed", lambda *_: self.display_changed())
        self.row(settings, "Primary display", self.display_primary)
        self.display_controls = {}
        for item in connected:
            card = self.card(body, item["name"])
            enabled = Gtk.Switch(active=item["enabled"])
            self.row(card, "Enabled", enabled)
            mode = item["mode"] or core.preferred_mode(item)
            resolution = combo([(value, value.replace("x", " × ")) for value in item["modes"]], mode)
            rates = item["modes"][mode]
            rate = combo([(value, f"{value} Hz") for value in rates], item["rate"] or max(rates, key=float))
            rotation = combo([(value, title) for value, title in (("normal", "Normal"), ("left", "Left"), ("right", "Right"), ("inverted", "Upside down"))], item["rotation"])
            scales = sorted(set([1.0, 1.25, 1.5, 1.75, 2.0, round(item["scale"], 3)]))
            scale = combo([(str(value), f"{value * 100:g}%") for value in scales], str(round(item["scale"], 3)))
            grid = Gtk.Grid(column_spacing=16, row_spacing=10)
            for index, (title, widget) in enumerate((("Resolution", resolution), ("Refresh rate", rate), ("Rotation", rotation), ("Scale", scale))):
                column, row = (index % 2) * 2, index // 2
                grid.attach(label(title, "dim"), column, row, 1, 1)
                grid.attach(widget, column + 1, row, 1, 1)
            card.pack_start(grid, False, False, 0)
            positions = box(False, 10)
            x, y = spin(item["x"], 0, 16384), spin(item["y"], 0, 16384)
            positions.pack_start(label("Position X / Y", "dim"), True, True, 0)
            positions.pack_end(y, False, False, 0)
            positions.pack_end(x, False, False, 0)
            card.pack_start(positions, False, False, 0)
            controls = {"enabled": enabled, "mode": resolution, "rate": rate, "rotation": rotation, "scale": scale, "x": x, "y": y}
            self.display_controls[item["name"]] = controls
            def mode_changed(_, item=item, rate=rate, resolution=resolution):
                selected = resolution.get_active_id()
                values = item["modes"][selected]
                update_combo(rate, [(value, f"{value} Hz") for value in values], max(values, key=float))
                self.display_changed()
            resolution.connect("changed", mode_changed)
            for key, widget in controls.items():
                if key == "mode":
                    continue
                widget.connect("notify::active" if key == "enabled" else "value-changed" if key in ("x", "y") else "changed",
                               lambda *_: self.display_changed())
        actions = box(False, 10)
        actions.pack_start(button("Arrange left to right", self.arrange_displays), False, False, 0)
        actions.pack_end(button("Apply…", lambda: self.apply_display(False), True), False, False, 0)
        actions.pack_end(button("Restore defaults…", lambda: self.apply_display(True)), False, False, 0)
        self.display_footer.pack_start(actions, False, False, 0)
        self.display_footer.pack_start(label("Changes revert after 15 seconds unless you keep them.", "dim", True), False, False, 0)
        if self.defaults.get("capabilities", {}).get("hasBacklight"):
            card = self.card(body, "Panel brightness")
            scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
            scale.set_hexpand(True)
            scale.set_value(70)
            self.row(card, "Brightness", scale)
            if not self.demo:
                def initial_brightness(value):
                    self.syncing = True
                    try:
                        if value is not None:
                            scale.set_value(value)
                    finally:
                        self.syncing = False
                self.run(core.brightness, initial_brightness)
            scale.connect("value-changed", lambda widget: self.defer_slider("brightness", lambda value=round(widget.get_value()): self.command(
                "brightnessctl", "--class=backlight", "--min-value=1", "set", f"{value}%")))
        self.dirty_display = False
        body.show_all()
        self.display_footer.show_all()

    def display_changed(self):
        self.dirty_display = True

    def display_plan(self):
        plan = {"layout": self.display_layout.get_active_id(), "outputs": []}
        for name, controls in self.display_controls.items():
            plan["outputs"].append({"name": name, "enabled": controls["enabled"].get_active(),
                "primary": name == self.display_primary.get_active_id(), "mode": controls["mode"].get_active_id(),
                "rate": controls["rate"].get_active_id(), "rotation": controls["rotation"].get_active_id(),
                "scale": float(controls["scale"].get_active_id()), "x": controls["x"].get_value_as_int(), "y": controls["y"].get_value_as_int()})
        return core.validate_display(plan, self.available_outputs)

    def arrange_displays(self):
        x = 0
        for controls in self.display_controls.values():
            controls["x"].set_value(x)
            controls["y"].set_value(0)
            if controls["enabled"].get_active():
                x += core.mode_size(controls["mode"].get_active_id(), controls["rotation"].get_active_id(), float(controls["scale"].get_active_id()))[0]
        self.display_changed()

    def apply_display(self, restore):
        def start():
            plan = core.default_display(self.available_outputs, self.defaults.get("display")) if restore else self.display_plan()
            if self.demo:
                self.demo.calls.append(("display", "preview"))
                self.prompt("Keep display changes?", "In the live app, this layout reverts automatically after 15 seconds.", False,
                            lambda value: self.preferences.update("display", None if restore else plan) if value else None)
                return
            self.notify("Applying display changes…")
            def begin():
                executable = Path(__file__).parent.parent.parent / "bin/blix-settings-apply"
                process = subprocess.Popen([str(executable), "display-preview"], stdin=subprocess.PIPE,
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
                process.stdin.write(json.dumps({"plan": plan, "restore": restore}) + "\n")
                process.stdin.flush()
                line = process.stdout.readline()
                if not line:
                    raise SettingsError(process.stderr.read().strip() or "The display preview could not start.")
                response = json.loads(line)
                if not response.get("ready"):
                    raise SettingsError("The display preview could not start.")
                return process
            self.run(begin, self.confirm_display)
        self.attempt(start)

    def confirm_display(self, process):
        self.preview = process
        dialog = Gtk.Dialog(title="Keep display changes?", transient_for=self, modal=True)
        dialog.add_button("Revert", Gtk.ResponseType.CANCEL)
        dialog.add_button("Keep changes", Gtk.ResponseType.OK)
        text = label("Reverting in 15 seconds…", wrap=True)
        content = dialog.get_content_area()
        content.set_border_width(24)
        content.pack_start(text, False, False, 0)
        self.dialogs.append(dialog)
        finished = False
        deadline = time.monotonic() + 15
        def response(_, value):
            nonlocal finished
            if finished:
                return
            finished = True
            dialog.destroy()
            self.dialogs.remove(dialog)
            try:
                process.stdin.write("keep\n" if value == Gtk.ResponseType.OK else "revert\n")
                process.stdin.flush()
            except (BrokenPipeError, ValueError):
                pass
            def wait():
                line = process.stdout.readline()
                process.wait(timeout=30)
                process.stdin.close()
                if not line:
                    raise SettingsError(process.stderr.read().strip() or "Could not finish the display change.")
                return json.loads(line)
            def done(result):
                self.preview = None
                self.dirty_display = False
                self.last_models.pop("display", None)
                if result.get("error"):
                    self.notify(result["error"], True)
                else:
                    self.notify("Display layout saved." if result.get("kept") else "Previous display layout restored.")
                self.refresh()
            self.run(wait, done, lambda error: done({"error": str(error)}))
        dialog.connect("response", response)
        def tick():
            if finished or self.closed:
                return False
            remaining = math.ceil(deadline - time.monotonic())
            if remaining <= 0:
                dialog.response(Gtk.ResponseType.CANCEL)
                return False
            text.set_text(f"Reverting in {remaining} seconds…")
            return True
        GLib.timeout_add_seconds(1, tick)
        dialog.show_all()

    def defer_slider(self, key, function):
        if self.syncing:
            return
        if key in self.pending_sliders:
            GLib.source_remove(self.pending_sliders.pop(key))
        def apply():
            self.pending_sliders.pop(key, None)
            if not self.closed:
                self.run(function)
            return False
        self.pending_sliders[key] = GLib.timeout_add(180, apply)

    def build_audio(self):
        body = self.pages["audio"]
        for kind, title in (("sink", "Output"), ("source", "Microphone")):
            card = self.card(body, title)
            devices = combo([])
            volume = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
            volume.set_size_request(300, -1)
            mute = Gtk.Switch()
            self.row(card, "Device", devices)
            self.row(card, "Volume", volume)
            self.row(card, "Muted", mute)
            self.controls[kind] = {"device": devices, "volume": volume, "mute": mute}
            devices.connect("changed", lambda widget, kind=kind: None if self.syncing or not widget.get_active_id() else
                            self.set_audio_device(kind, widget.get_active_id()))
            volume.connect("value-changed", lambda widget, kind=kind, devices=devices: self.defer_slider(kind,
                           lambda name=devices.get_active_id(), value=round(widget.get_value()): self.command("pactl", f"set-{kind}-volume", name, f"{value}%")))
            mute.connect("notify::active", lambda widget, _, kind=kind, devices=devices: None if self.syncing or not devices.get_active_id() else
                         self.run(lambda name=devices.get_active_id(), value=int(widget.get_active()): self.command("pactl", f"set-{kind}-mute", name, value)))
        self.pages["audio"].pack_start(button("Test output sound", self.test_sound), False, False, 0)
        test = box(False, 12)
        self.meter_button = button("Test microphone", self.toggle_meter)
        self.meter_level = Gtk.LevelBar()
        self.meter_level.set_hexpand(True)
        test.pack_start(self.meter_button, False, False, 0)
        test.pack_start(self.meter_level, True, True, 0)
        body.pack_start(test, False, False, 0)
        body.pack_start(label("Microphone testing listens only while this page is open. No recording is saved.", "dim", True), False, False, 0)

    def set_audio_device(self, kind, name):
        if kind == "source":
            self.stop_meter()
        self.run(lambda: self.command("pactl", f"set-default-{kind}", name), lambda _: self.refresh())

    def update_audio(self, state):
        self.syncing = True
        try:
            for kind, plural in (("sink", "sinks"), ("source", "sources")):
                widgets = self.controls[kind]
                update_combo(widgets["device"], [(item["name"], item["description"]) for item in state[plural]], state[kind])
                device = next((item for item in state[plural] if item["name"] == state[kind]), None)
                for widget in widgets.values():
                    widget.set_sensitive(bool(device))
                if device and kind not in self.pending_sliders:
                    widgets["volume"].set_value(min(100, device["volume"]))
                    widgets["mute"].set_active(device["mute"])
        finally:
            self.syncing = False

    def test_sound(self):
        device = self.controls["sink"]["device"].get_active_id()
        if not device:
            self.notify("Select an output device first.", True)
            return
        self.run(lambda: self.command("paplay", "--device", device, str(Path(__file__).with_name("test.wav"))))

    def toggle_meter(self):
        if self.meter:
            self.stop_meter()
            return
        if self.demo:
            self.demo.calls.append(("microphone", "test"))
            self.meter_level.set_value(0.55)
            return
        source = self.controls["source"]["device"].get_active_id()
        if not source:
            self.notify("Select a microphone first.", True)
            return
        try:
            process = subprocess.Popen([core.TOOLS["parec"], "--device", source, "--raw", "--format=s16le",
                                        "--rate=16000", "--channels=1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except OSError as error:
            self.notify(str(error), True)
            return
        self.meter = process
        self.meter_button.set_label("Stop microphone test")
        def read():
            while self.meter is process and not self.closed:
                data = process.stdout.read(1600)
                if not data:
                    break
                samples = array.array("h", data[:len(data) // 2 * 2])
                level = min(1, math.sqrt(sum(value * value for value in samples) / max(1, len(samples))) / 8192)
                GLib.idle_add(lambda level=level: self.meter_level.set_value(level) if self.meter is process else None)
            GLib.idle_add(lambda: self.stop_meter() if self.meter is process else None)
        threading.Thread(target=read, daemon=True).start()

    def stop_meter(self):
        if self.meter:
            process, self.meter = self.meter, None
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if hasattr(self, "meter_button"):
            self.meter_button.set_label("Test microphone")
            self.meter_level.set_value(0)

    def build_radio(self, page, state):
        model = repr(state)
        if self.last_models.get(page) == model:
            return
        self.last_models[page] = model
        body = self.clear(page)
        if page == "network":
            self.build_network(body, state)
        else:
            self.build_bluetooth(body, state)
        body.show_all()

    def build_network(self, body, state):
        card = self.card(body)
        enabled = Gtk.Switch(active=state["enabled"])
        enabled.set_sensitive(state["available"])
        enabled.connect("notify::active", lambda widget, _: self.attempt(lambda: self.network.toggle(widget.get_active())))
        self.row(card, "Wi-Fi", enabled, "Disabled by hardware" if not state["available"] else None)
        card.pack_start(button("Scan for networks", lambda: self.attempt(lambda: self.network.scan(self.radio_done))), False, False, 0)
        networks = self.card(body, "Nearby networks")
        if not state["networks"]:
            networks.pack_start(label("No networks found. Enable Wi-Fi and scan.", "dim"), False, False, 0)
        for item in state["networks"]:
            status = "Connected" if item["active"] else "Connecting…" if item.get("connecting") else f"{item['strength']}% signal · " + ("Open" if item["security"] == "open" else "Secured")
            action = button("Disconnect" if item["active"] else "Connecting…" if item.get("connecting") else "Connect", lambda item=item: self.connect_wifi(item))
            action.set_sensitive(state["enabled"] and not item.get("connecting"))
            self.row(networks, item["name"], action, status)
        if state["wired"]:
            wired = self.card(body, "Ethernet")
            for item in state["wired"]:
                self.row(wired, item["name"], label(item["status"]), item["address"] or None)
        if state["profiles"]:
            saved = self.card(body, "Saved connections")
            for item in state["profiles"]:
                actions = box(False, 8)
                actions.pack_start(button("Disconnect" if item["active"] else "Connect",
                    lambda item=item: self.attempt(lambda: (self.network.disconnect if item["active"] else self.network.activate)(item["uuid"], self.radio_done))), False, False, 0)
                actions.pack_start(button("Forget…", lambda item=item: self.prompt("Forget connection?", f"Remove {item['name']} and its saved credentials?", False,
                    lambda answer: self.attempt(lambda: self.network.forget(item["uuid"], self.radio_done)) if answer else None)), False, False, 0)
                self.row(saved, item["name"], actions)
        body.pack_start(button("Advanced connections…", self.advanced_connections), False, False, 0)

    def connect_wifi(self, item):
        if item["active"]:
            if item["saved"]:
                self.attempt(lambda: self.network.disconnect(item["saved"], self.radio_done))
            return
        if item["security"] in ("enterprise", "wep") and not item["saved"]:
            self.notify("Use Advanced Connections for this network's authentication.")
            self.advanced_connections()
            return
        def connect(password=None):
            self.notify(f"Connecting to {item['name']}…")
            self.attempt(lambda: self.network.connect_network(item, password, self.radio_done))
        if item["security"] in ("wpa", "sae") and not item["saved"]:
            self.prompt("Wi-Fi password", f"Password for {item['name']}", True,
                        lambda password: connect(password) if password is not None else None, secret=True)
        else:
            connect()

    def build_bluetooth(self, body, state):
        if not state["adapters"]:
            body.pack_start(label("No Bluetooth adapter was found."), False, False, 0)
            return
        for adapter in state["adapters"]:
            card = self.card(body, adapter["name"])
            powered = Gtk.Switch(active=adapter["powered"])
            powered.connect("notify::active", lambda widget, _, adapter=adapter:
                            self.attempt(lambda: self.bluetooth.toggle(adapter["path"], widget.get_active())))
            self.row(card, "Bluetooth", powered)
            scanning = adapter.get("discovering")
            scan = button("Stop discovery" if scanning else "Find devices",
                lambda adapter=adapter, scanning=scanning: self.attempt(lambda:
                    self.bluetooth.stop_scan() if scanning else self.bluetooth.scan(adapter["path"])))
            scan.set_sensitive(adapter["powered"])
            card.pack_start(scan, False, False, 0)
            for item in state["devices"]:
                if item["adapter"] != adapter["path"]:
                    continue
                actions = box(False, 8)
                action = "Disconnect" if item["connected"] else "Connect" if item["paired"] else "Pair"
                connect = button(action, lambda item=item, action=action: self.attempt(lambda: self.bluetooth.action(item, action, self.radio_done)))
                connect.set_sensitive(adapter["powered"])
                actions.pack_start(connect, False, False, 0)
                if item["paired"]:
                    actions.pack_start(button("Forget…", lambda item=item: self.prompt("Forget Bluetooth device?", f"Remove pairing with {item['name']}?", False,
                        lambda answer: self.attempt(lambda: self.bluetooth.action(item, "RemoveDevice", self.radio_done)) if answer else None)), False, False, 0)
                self.row(card, item["name"], actions, "Connected" if item["connected"] else "Paired" if item["paired"] else "Not paired")

    def build_power(self):
        body = self.pages["power"]
        self.battery_card = self.card(body, "Battery")
        card = self.card(body, "Screen")
        saved = self.preferences.read().get("blank_seconds", self.defaults.get("display", {}).get("blankAfterSeconds", 0))
        self.blank_minutes = spin(saved / 60, 0, 1440)
        self.row(card, "Turn screen off after", self.blank_minutes, "Minutes of inactivity. Zero keeps the display on.")
        actions = box(False, 10)
        actions.pack_start(button("Apply", self.save_blank, True), False, False, 0)
        actions.pack_start(button("Restore defaults", lambda: self.save_blank(True)), False, False, 0)
        card.pack_start(actions, False, False, 0)
        session = self.card(body, "Session")
        controls = box(False, 10)
        controls.pack_start(button("Lock screen", lambda: self.session_action(False)), False, False, 0)
        controls.pack_start(button("Suspend…", lambda: self.prompt("Suspend device?", "The screen will lock before suspending.", False,
                            lambda answer: self.session_action(True) if answer else None)), False, False, 0)
        session.pack_start(controls, False, False, 0)

    def update_batteries(self, items):
        for child in self.battery_card.get_children()[1:]:
            self.battery_card.remove(child)
        if not items:
            self.battery_card.pack_start(label("No battery was detected.", "dim"), False, False, 0)
        for item in items:
            suffix = f"Charge limit: {item['charge_limit']}%" if item["charge_limit"] else None
            self.row(self.battery_card, item["name"], label(f"{item['capacity']}% · {item['status']}"), suffix)
        self.battery_card.show_all()

    def save_blank(self, restore=False):
        seconds = self.defaults.get("display", {}).get("blankAfterSeconds", 0) if restore else round(self.blank_minutes.get_value() * 60)
        def apply():
            self.command("xset", "dpms", 0, 0, seconds)
            self.preferences.update("blank_seconds", None if restore else seconds)
        self.run(apply, lambda _: (self.blank_minutes.set_value(seconds / 60), self.notify("Screen-off timer saved.")))

    def session_action(self, suspend):
        if self.demo:
            self.demo.calls.append(("session", "suspend" if suspend else "lock"))
            return
        def apply():
            lock = self.defaults.get("lockCommand")
            if not lock:
                raise SettingsError("Activate the Blix configuration before using session controls.")
            result = subprocess.run([lock], capture_output=True, text=True, timeout=15)
            if result.returncode:
                raise SettingsError(result.stderr.strip() or "Could not lock the screen; suspend was canceled.")
            if suspend:
                self.command("systemctl", "suspend")
        self.run(apply)

    def build_input(self, devices):
        body = self.clear("input")
        self.input_controls = {}
        if not devices:
            body.pack_start(label("No configurable libinput pointing devices were found.", "dim", True), False, False, 0)
        for device in devices:
            card = self.card(body, device["name"])
            speed = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, -1, 1, 0.05)
            speed.set_digits(2)
            speed.set_value(device["speed"])
            speed.set_size_request(250, -1)
            self.row(card, "Pointer speed", speed)
            controls = {"speed": speed}
            for key, title in (("natural", "Natural scrolling"), ("tapping", "Tap to click")):
                if device[key] is not None:
                    widget = Gtk.Switch(active=device[key])
                    controls[key] = widget
                    self.row(card, title, widget)
            self.input_controls[device["key"]] = (device, controls)
            actions = box(False, 10)
            actions.pack_start(button("Apply", lambda device=device: self.save_input(device, False), True), False, False, 0)
            actions.pack_start(button("Restore defaults", lambda device=device: self.save_input(device, True)), False, False, 0)
            card.pack_start(actions, False, False, 0)
        keyboard = self.card(body, "Keyboard repeat")
        baseline = self.defaults.get("keyboard", {"delay": 200, "rate": 50})
        current = self.preferences.read().get("keyboard", baseline)
        self.repeat_delay = spin(current["delay"], 100, 2000, 25)
        self.repeat_rate = spin(current["rate"], 1, 100)
        self.row(keyboard, "Initial delay", self.repeat_delay, "Milliseconds before a held key starts repeating.")
        self.row(keyboard, "Repeat rate", self.repeat_rate, "Characters per second.")
        actions = box(False, 10)
        actions.pack_start(button("Apply", self.save_keyboard, True), False, False, 0)
        actions.pack_start(button("Restore defaults", lambda: self.save_keyboard(True)), False, False, 0)
        keyboard.pack_start(actions, False, False, 0)
        body.show_all()

    def save_input(self, device, restore):
        controls = self.input_controls[device["key"]][1]
        values = self.defaults.get("input", {}).get("touchpad" if device["touchpad"] else "mouse", {"speed": 0, "natural": True}) if restore else {
            key: widget.get_value() if key == "speed" else widget.get_active() for key, widget in controls.items()}
        def apply():
            if self.demo:
                self.demo.calls.append(("input", device["key"], values))
                self.demo.devices[0].update(values)
            else:
                live = next((item for item in core.input_devices() if item["key"] == device["key"]), None)
                if not live:
                    raise SettingsError("This pointing device was disconnected.")
                core.set_input(live, values)
            saved = self.preferences.read().get("input_devices", {})
            saved.pop(device["key"], None) if restore else saved.update({device["key"]: values})
            self.preferences.update("input_devices", saved or None)
        self.run(apply, lambda _: (self.notify("Pointing-device settings saved."), self.last_models.pop("input", None), self.refresh()))

    def save_keyboard(self, restore=False):
        value = self.defaults.get("keyboard", {"delay": 200, "rate": 50}) if restore else {
            "delay": self.repeat_delay.get_value_as_int(), "rate": self.repeat_rate.get_value_as_int()}
        def apply():
            self.command("xset", "r", "rate", value["delay"], value["rate"])
            self.preferences.update("keyboard", None if restore else value)
        self.run(apply, lambda _: (self.repeat_delay.set_value(value["delay"]), self.repeat_rate.set_value(value["rate"]), self.notify("Keyboard repeat saved.")))

    def build_shortcuts(self):
        body = self.pages["shortcuts"]
        card = self.card(body)
        search = Gtk.SearchEntry(placeholder_text="Filter shortcuts…")
        card.pack_start(search, False, False, 0)
        shortcuts = core.shortcut_reference(None if self.demo else self.defaults.get("shortcutsFile"))
        shortcuts += [("Ctrl + F", "Search settings (in this app)"), ("F5", "Refresh devices (in this app)"),
                      ("Escape", "Clear search / close settings")]
        rows = []
        for key, title in shortcuts:
            content = box(False, 20)
            content.pack_start(label(title), True, True, 0)
            content.pack_end(label(key, "dim"), False, False, 0)
            card.pack_start(content, False, False, 0)
            rows.append((content, (key + " " + title).lower()))
        search.connect("search-changed", lambda widget: [row.set_visible(widget.get_text().lower() in text) for row, text in rows])

    def build_about(self):
        body = self.pages["about"]
        card = self.card(body)
        values = [("System", "NixOS · Blix desktop"), ("Device", "Preview device"), ("Session", "OXWM / X11"),
                  ("Memory", "16 GiB"), ("Blix Settings", "0.1.0")] if self.demo else core.system_info()
        for key, value in values:
            text = label(value, "dim", True)
            text.set_selectable(True)
            self.row(card, key, text)
        body.pack_start(label("Nix provides the defaults. Display and input choices are saved for your user; audio, connections and pairing are remembered by their services.", "dim", True), False, False, 0)

    def close_window(self, *_):
        if self.closed:
            return False
        self.closed = True
        GLib.source_remove(self.poll)
        for source in self.pending_sliders.values():
            GLib.source_remove(source)
        self.pending_sliders.clear()
        self.stop_meter()
        if self.preview and self.preview.stdin:
            self.preview.stdin.close()
        if self.bluetooth:
            self.bluetooth.close()
        for dialog in self.dialogs[:]:
            dialog.response(Gtk.ResponseType.CANCEL)
        self.executor.shutdown(wait=False, cancel_futures=True)
        return False


class Application(Gtk.Application):
    def __init__(self, demo=False):
        super().__init__(application_id="org.blix.Settings.Preview" if demo else "org.blix.Settings",
                         flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.demo = demo
        self.window = None

    def do_activate(self):
        if self.window is None or self.window.closed:
            self.window = Window(self, self.demo)
        self.window.present()

    def do_shutdown(self):
        if self.window:
            self.window.close_window()
        Gtk.Application.do_shutdown(self)
