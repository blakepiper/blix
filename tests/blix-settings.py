"""Test commands and failure recovery in isolation; never alter a live session."""
import copy
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import Mock, patch

source = Path(sys.argv.pop(1))
sys.path.insert(0, str(source))
import core
from core import SettingsError


QUERY = """eDP-1 connected primary 2880x1800+0+0 (normal left inverted right x axis y axis)
   2880x1800 60.00*+ 120.00
   1920x1080 60.00 120.00
HDMI-2 connected 1920x1080+2880+0 (normal left inverted right x axis y axis)
   1920x1080 60.00*+ 144.00
   1280x720 60.00
"""


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="blix-settings-test-")
        self.root = Path(self.temp.name)
        self.environment = patch.dict(os.environ, XDG_CONFIG_HOME=str(self.root / "config"),
                                      XDG_RUNTIME_DIR=str(self.root / "runtime"), DISPLAY=":999")
        self.environment.start()
        (self.root / "runtime").mkdir(mode=0o700)
        self.available = core.parse_outputs(QUERY)
        self.plan = core.default_display(self.available, {"primaryOutput": "eDP-1", "layout": "extend"})

    def tearDown(self):
        self.environment.stop()
        self.temp.cleanup()

    def test_transparency_reloads_picom_and_survives_the_next_session(self):
        original = (source / "picom.conf").read_text()
        self.assertTrue(core.transparency_enabled())
        self.assertEqual(core.prepare_picom_configuration().read_text(), original)
        preferences = core.Preferences()
        preferences.update("blank_seconds", 600)
        with patch.object(core, "command") as command:
            core.set_transparency(False)
            command.assert_called_once_with("systemctl", "--user", "reload", "blix-picom.service")
        self.assertFalse(core.transparency_enabled())
        path = core.prepare_picom_configuration()
        self.assertIn(", { opacity = 1.0; opacity-override = true; }", path.read_text())
        with patch.object(core, "command"):
            core.set_transparency(True)
        self.assertEqual(path.read_text(), original)
        self.assertNotIn("transparency", preferences.read())
        self.assertEqual(preferences.read()["blank_seconds"], 600)

    def test_transparency_failure_restores_the_previous_opacity_and_preference(self):
        for enabled in (False, True):
            preferences = core.Preferences()
            preferences.update("transparency", not enabled)
            original = core.prepare_picom_configuration().read_text()
            with patch.object(core, "command", side_effect=SettingsError("Compositor reload failed")):
                with self.assertRaisesRegex(SettingsError, "Compositor reload failed"):
                    core.set_transparency(enabled)
            self.assertEqual(core.transparency_enabled(), not enabled)
            self.assertEqual((core.runtime_root() / "picom.conf").read_text(), original)

    def test_invalid_transparency_is_rejected_before_changing_the_compositor(self):
        with patch.object(core, "command") as command:
            for value in (None, 0, "off"):
                with self.assertRaises(SettingsError):
                    core.set_transparency(value)
            core.Preferences().update("transparency", "off")
            with self.assertRaises(SettingsError):
                core.prepare_picom_configuration()
            command.assert_not_called()

    def test_rates_are_per_output_and_per_resolution(self):
        plan = copy.deepcopy(self.plan)
        plan["layout"] = "mirror"
        for item in plan["outputs"]:
            actual = next(output for output in self.available if output["name"] == item["name"])
            item.update(mode="1920x1080", rate=core.choose_rate(actual, "1920x1080"))
        core.validate_display(plan, self.available)
        self.assertEqual([item["rate"] for item in plan["outputs"]], ["120.00", "144.00"])
        plan["outputs"][1]["rate"] = "240.00"
        with self.assertRaises(SettingsError):
            core.validate_display(plan, self.available)

    def test_display_never_accepts_all_off_or_two_primary(self):
        plan = copy.deepcopy(self.plan)
        for item in plan["outputs"]:
            item["enabled"] = False
        with self.assertRaises(SettingsError):
            core.validate_display(plan, self.available)
        plan = copy.deepcopy(self.plan)
        plan["outputs"][1]["primary"] = True
        with self.assertRaises(SettingsError):
            core.validate_display(plan, self.available)

    def test_scaled_rotated_snapshot_and_new_dock(self):
        verbose = """DSI-1 connected primary 2340x1080+0+0 left (normal left inverted right x axis y axis)
    Transform: 0.666667 0.000000 0.000000
               0.000000 0.666667 0.000000
               0.000000 0.000000 1.000000
   1080x2340 60.00*+
"""
        output = core.parse_outputs(verbose)[0]
        self.assertEqual(output["rotation"], "left")
        self.assertAlmostEqual(output["scale"], 1.5, places=2)
        snapshot = core.snapshot_display([output])
        self.assertIn(output["transform"], core.display_args(snapshot, snapshot=True))
        changed = copy.deepcopy(self.available)
        changed[1]["name"] = "DP-2-1"
        plan = core.saved_display(changed, self.plan)
        self.assertEqual([item["name"] for item in plan["outputs"]], ["eDP-1", "DP-2-1"])
        self.assertEqual(plan["outputs"][1]["rate"], "144.00")
        self.assertGreaterEqual(plan["outputs"][1]["x"], 2880)

    def test_preferences_preserve_other_pages_and_are_private(self):
        preferences = core.Preferences()
        preferences.update("display", self.plan)
        preferences.update("keyboard", {"delay": 250, "rate": 40})
        preferences.update("display", None)
        self.assertEqual(preferences.read()["keyboard"], {"delay": 250, "rate": 40})
        self.assertNotIn("display", preferences.read())
        self.assertEqual(preferences.path.stat().st_mode & 0o777, 0o600)

    def test_saved_layout_ignores_active_markers_and_preview(self):
        core.Preferences().update("display", self.plan)
        with patch.object(core, "outputs", return_value=self.available), patch.object(core, "command") as command:
            self.assertEqual(core.apply_saved_display(), 0)
            self.assertEqual(command.call_count, 1)
            self.assertEqual(core.apply_saved_display(), 0)
            self.assertEqual(command.call_count, 1)
            core.atomic_json(core.runtime_root() / "display-preview.json", {"pid": os.getpid(), "expires": time.time() + 30})
            self.assertEqual(core.apply_saved_display(), 3)
            self.assertEqual(command.call_count, 1)

    def test_keyboard_blank_and_device_reconnect_reapply_saved_choices(self):
        prefs = core.Preferences()
        prefs.update("keyboard", {"delay": 300, "rate": 35})
        prefs.update("blank_seconds", 600)
        prefs.update("input_devices", {"touchpad": {"speed": 0.2, "natural": False, "tapping": True}})
        device = {"id": "28", "key": "touchpad", "natural": True, "tapping": True}
        with patch.object(core, "input_devices", return_value=[device]), patch.object(core, "command") as command:
            core.apply_session_preferences()
            calls = [call.args for call in command.call_args_list]
            self.assertIn(("xset", "r", "rate", 300, 35), calls)
            self.assertIn(("xset", "dpms", 0, 0, 600), calls)
            self.assertIn(("xinput", "set-prop", "28", "libinput Accel Speed", 0.2), calls)
            self.assertIn(("xinput", "set-prop", "28", "libinput Natural Scrolling Enabled", 0), calls)

    def test_audio_uses_names_and_ignores_monitor_sources(self):
        def command(name, *args, **_):
            if args[-1] in ("sinks", "sources"):
                return json.dumps([{"name": "speaker" if args[-1] == "sinks" else "mic", "description": "Device",
                    "volume": {"front-left": {"value": 32768}}, "mute": False},
                    *([{ "name": "speaker.monitor", "volume": {}, "mute": False }] if args[-1] == "sources" else [])])
            return "speaker" if args[-1] == "get-default-sink" else "mic"
        with patch.object(core, "command", side_effect=command):
            audio = core.audio_state()
        self.assertEqual(len(audio["sources"]), 1)
        self.assertEqual(audio["sinks"][0]["volume"], 50)

    def test_live_x11_session_values_override_saved_defaults(self):
        core.Preferences().update("keyboard", {"delay": 600, "rate": 20})
        core.Preferences().update("blank_seconds", 600)
        query = "auto repeat delay: 275    repeat rate: 42\nStandby: 0    Suspend: 0    Off: 90\nDPMS is Enabled"
        with patch.object(core, "command", return_value=query):
            state = core.session_state()
        self.assertEqual(state, {"keyboard": {"delay": 275, "rate": 42}, "blank_seconds": 90})
        with patch.object(core, "command", return_value=query.replace("Enabled", "Disabled")):
            self.assertEqual(core.session_state()["blank_seconds"], 0)

    def test_display_snapshot_reads_brightness_each_time_and_survives_missing_backlight(self):
        with patch.object(core, "outputs", return_value=self.available), patch.object(core, "command", return_value="Xft.dpi:\t120\n"), \
                patch.object(core, "brightness", side_effect=[25, 100, SettingsError("Backlight unavailable")]):
            self.assertEqual(core.display_state()["brightness"], 25)
            self.assertEqual(core.display_state()["brightness"], 100)
            state = core.display_state()
        self.assertEqual(state["outputs"], self.available)
        self.assertEqual(state["dpi"], 120)
        self.assertIsNone(state["brightness"])
        self.assertIn("unavailable", state["brightness_error"])

    def watchdog(self, answer):
        log = self.root / "commands.jsonl"
        fake = self.root / "xrandr"
        fake.write_text(f"#!{sys.executable}\nimport json, sys\nfrom pathlib import Path\n"
                        f"query = {QUERY!r}\n"
                        f"if sys.argv[1] in ('--query', '--verbose'): print(query)\n"
                        f"else:\n with Path({str(log)!r}).open('a') as stream: stream.write(json.dumps(sys.argv[1:]) + '\\n')\n")
        fake.chmod(0o755)
        driver = self.root / "guard.py"
        driver.write_text(f"import sys, json\nsys.path.insert(0, {str(source)!r})\nimport core\n"
                          f"core.TOOLS['xrandr'] = {str(fake)!r}\n"
                          "core.preview_display(json.loads(sys.stdin.readline()), seconds=0.4)\n")
        process = subprocess.Popen([sys.executable, str(driver)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        process.stdin.write(json.dumps({"plan": self.plan}) + "\n")
        process.stdin.flush()
        self.assertTrue(select.select([process.stdout], [], [], 8)[0], "Watchdog did not become ready")
        self.assertTrue(json.loads(process.stdout.readline())["ready"])
        if answer == "crash":
            process.stdin.close()
        elif answer:
            process.stdin.write(answer + "\n")
            process.stdin.flush()
        self.assertTrue(select.select([process.stdout], [], [], 8)[0], "Watchdog did not finish")
        result = json.loads(process.stdout.readline())
        self.assertEqual(process.wait(timeout=8), 0, process.stderr.read())
        if not process.stdin.closed:
            process.stdin.close()
        process.stdout.close()
        process.stderr.close()
        commands = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertFalse((core.runtime_root() / "display-preview.json").exists())
        return result, commands

    def test_watchdog_keeps_only_confirmed_changes(self):
        result, commands = self.watchdog("keep")
        self.assertTrue(result["kept"])
        self.assertEqual(len(commands), 1)
        self.assertEqual(core.Preferences().read()["display"], self.plan)

    def test_watchdog_restores_on_revert_timeout_and_gui_crash(self):
        for answer in ("revert", None, "crash"):
            with self.subTest(answer=answer):
                (self.root / "commands.jsonl").unlink(missing_ok=True)
                result, commands = self.watchdog(answer)
                self.assertFalse(result["kept"])
                self.assertEqual(len(commands), 2)
                self.assertIn("--transform", commands[-1])
                self.assertNotIn("display", core.Preferences().read())


class WifiTests(unittest.TestCase):
    def test_active_access_point_wins_over_a_stronger_duplicate(self):
        import gi
        gi.require_version("NM", "1.0")
        from gi.repository import GLib, NM
        from radios import Network
        connection = Mock()
        connection.get_uuid.return_value = "actual-active-profile"
        connection.get_state.return_value = NM.ActiveConnectionState.ACTIVATED
        device = Mock()
        device.get_device_type.return_value = NM.DeviceType.WIFI
        device.get_state.return_value = NM.DeviceState.ACTIVATED
        device.get_path.return_value = "/device/wifi"
        device.get_active_connection.return_value = connection
        device.get_available_connections.return_value = []
        def ap(path, strength):
            point = Mock()
            point.get_ssid.return_value = GLib.Bytes.new(b"Shared SSID")
            point.get_flags.return_value = 1
            point.get_wpa_flags.return_value = 0x100
            point.get_rsn_flags.return_value = 0
            point.get_path.return_value = path
            point.get_strength.return_value = strength
            return point
        connected, stronger = ap("/ap/connected", 42), ap("/ap/stronger", 100)
        device.get_active_access_point.return_value = connected
        network = Network.__new__(Network)
        network.client = Mock()
        network.client.get_nm_running.return_value = True
        network.client.get_devices.return_value = [device]
        network.client.get_active_connections.return_value = [connection]
        network.client.get_connections.return_value = []
        network.client.wireless_get_enabled.return_value = True
        network.client.wireless_hardware_get_enabled.return_value = True
        for points in ([connected, stronger], [stronger, connected]):
            device.get_access_points.return_value = points
            item = network.snapshot()["networks"][0]
            self.assertTrue(item["active"])
            self.assertEqual(item["strength"], 42)
            self.assertEqual(item["active_uuid"], "actual-active-profile")
        device.get_state.return_value = NM.DeviceState.PREPARE
        item = network.snapshot()["networks"][0]
        self.assertFalse(item["active"])
        self.assertTrue(item["connecting"])
        self.assertEqual(item["path"], "/ap/connected")

    def test_saved_connection_states_distinguish_activation_and_deactivation(self):
        from gi.repository import NM
        from radios import Network
        network = Network.__new__(Network)
        network.client = Mock()
        network.client.get_devices.return_value = []
        profile = Mock()
        profile.get_id.return_value = "Example"
        profile.get_uuid.return_value = "example"
        profile.get_connection_type.return_value = "802-11-wireless"
        network.client.get_connections.return_value = [profile]
        active = Mock()
        active.get_uuid.return_value = "example"
        network.client.get_active_connections.return_value = [active]
        active.get_state.return_value = NM.ActiveConnectionState.ACTIVATING
        state = network.snapshot()
        self.assertFalse(state["available"])
        self.assertFalse(state["profiles"][0]["active"])
        self.assertTrue(state["profiles"][0]["connecting"])
        active.get_state.return_value = NM.ActiveConnectionState.DEACTIVATING
        self.assertTrue(network.snapshot()["profiles"][0]["disconnecting"])
        profile.get_connection_type.return_value = "loopback"
        self.assertEqual(network.snapshot()["profiles"], [])

    def test_shortcut_reference_reads_current_bindings(self):
        with tempfile.TemporaryDirectory(prefix="blix-shortcut-test-") as directory:
            path = Path(directory) / "config.lua"
            path.write_text('local mod = "Mod4"\noxwm.key.bind({ mod, "Shift" }, "S", oxwm.spawn("screenshot-region"))\n')
            self.assertEqual(core.shortcut_reference(path), [("Super + Shift + S", "Region screenshot")])
            path.write_text('local mod = "Mod1"\noxwm.key.bind({ mod }, "F", oxwm.spawn("firefox"))\n')
            self.assertEqual(core.shortcut_reference(path), [("Alt + F", "Firefox")])

    def test_wifi_profiles_and_security(self):
        from radios import wifi_connection, wifi_security
        self.assertEqual(wifi_security(1, 0, 0x200), "enterprise")
        self.assertEqual(wifi_security(1, 0, 0x400), "sae")
        self.assertEqual(wifi_security(1, 0x100, 0), "wpa")
        for security in ("open", "wpa", "sae", "owe"):
            with self.subTest(security=security):
                profile = wifi_connection(b"Test: network", security, "test-password" if security in ("wpa", "sae") else None)
                self.assertTrue(profile.verify())
                self.assertEqual(bytes(profile.get_setting_wireless().get_ssid().get_data()), b"Test: network")
                self.assertEqual(profile.get_setting_connection().get_num_permissions(), 1)
        with self.assertRaises(SettingsError):
            wifi_connection(b"Test", "enterprise")

    def test_bluetooth_pairing_requires_user_confirmation(self):
        import dbus
        from radios import PairingAgent
        from unittest.mock import Mock
        pending = []
        def prompt(title, message, entry, callback):
            pending.append((message, callback))
            return lambda: callback(None)
        from dbus.mainloop.glib import DBusGMainLoop
        agent = PairingAgent(dbus.SessionBus(mainloop=DBusGMainLoop()), prompt, lambda *_: None)
        try:
            reply, error = Mock(), Mock()
            agent.RequestConfirmation("/device", 1234, reply, error)
            reply.assert_not_called()
            self.assertIn("001234", pending[-1][0])
            pending[-1][1](True)
            reply.assert_called_once_with()
            error.assert_not_called()
            reply, error = Mock(), Mock()
            agent.RequestPasskey("/device", reply, error)
            pending[-1][1]("not-a-number")
            reply.assert_not_called()
            error.assert_called_once()
            reply, error = Mock(), Mock()
            agent.RequestAuthorization("/device", reply, error)
            agent.Cancel()
            reply.assert_not_called()
            error.assert_called_once()
        finally:
            agent.remove_from_connection()

    def test_bluetooth_agent_registration_preserves_the_session_default(self):
        import dbus
        from dbus.mainloop.glib import DBusGMainLoop
        from radios import Bluetooth
        from unittest.mock import Mock
        bus = dbus.SessionBus(mainloop=DBusGMainLoop())
        bus.request_name("org.bluez")
        self.addCleanup(bus.release_name, "org.bluez")
        manager = Mock()
        with patch("radios.dbus.SystemBus", return_value=bus), patch("radios.dbus.Interface", return_value=manager):
            bluetooth = Bluetooth(lambda: None, lambda *_: None, lambda *_: None)
            try:
                manager.RegisterAgent.assert_called_once_with("/org/blix/Settings/agent", "KeyboardDisplay", timeout=3)
                manager.RequestDefaultAgent.assert_not_called()
            finally:
                bluetooth.close()
            manager.UnregisterAgent.assert_called_once_with("/org/blix/Settings/agent", timeout=3)
            # A failed registration must release its exported path as well.
            manager.RegisterAgent.side_effect = dbus.DBusException("Bluetooth unavailable")
            with self.assertRaises(dbus.DBusException):
                Bluetooth(lambda: None, lambda *_: None, lambda *_: None)
            manager.RegisterAgent.side_effect = None
            Bluetooth(lambda: None, lambda *_: None, lambda *_: None).close()


class GuiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        read_fd, write_fd = os.pipe()
        cls.display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x1024x24", "-nolisten", "tcp"],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, pass_fds=(write_fd,))
        def cleanup_display():
            if cls.display.poll() is None:
                cls.display.terminate()
                cls.display.wait(timeout=5)
            cls.display.stderr.close()
        cls.addClassCleanup(cleanup_display)
        os.close(write_fd)
        with os.fdopen(read_fd) as stream:
            if not select.select([stream], [], [], 10)[0]:
                raise RuntimeError("Xvfb did not start")
            os.environ["DISPLAY"] = ":" + stream.readline().strip()
        from gi.repository import GLib
        from ui import Application, Window
        cls.GLib = GLib
        cls.app = Application(demo=True)
        cls.app.register(None)
        cls.window = Window(cls.app, demo=True)
        cls.app.window = cls.window
        cls.callback_errors = []
        original_hook = sys.excepthook
        sys.excepthook = lambda kind, value, trace: cls.callback_errors.append(f"{kind.__name__}: {value}")
        cls.addClassCleanup(setattr, sys, "excepthook", original_hook)
        cls.pump()
        if os.environ.get("BLIX_SETTINGS_SCREENSHOT"):
            from gi.repository import Gdk
            surface = cls.window.get_window()
            Gdk.pixbuf_get_from_window(surface, 0, 0, cls.window.get_allocated_width(), cls.window.get_allocated_height()).savev(
                os.environ["BLIX_SETTINGS_SCREENSHOT"], "png", [], [])

    @classmethod
    def pump(cls, seconds=0.25):
        deadline = time.monotonic() + seconds
        context = cls.GLib.MainContext.default()
        while time.monotonic() < deadline:
            while context.pending():
                context.iteration(False)
            time.sleep(0.005)

    @classmethod
    def tearDownClass(cls):
        cls.window.close_window()
        cls.window.destroy()
        cls.pump()

    def page(self, name):
        self.window.sidebar.select_row(next(row for row in self.window.sidebar.get_children() if row.page_name == name))
        self.window.refresh()
        self.pump()

    def setUp(self):
        from demo import Demo, DemoPreferences, DemoRadio
        self.pump()
        self.window.demo = Demo()
        self.window.defaults = self.window.demo.defaults
        self.window.preferences = DemoPreferences()
        self.window.network = DemoRadio(self.window.demo, "network")
        self.window.bluetooth = DemoRadio(self.window.demo, "bluetooth")
        self.window.last_models.clear()
        self.window.dirty_display = self.window.dirty_keyboard = self.window.dirty_blank = False
        self.window.dirty_inputs.clear()
        self.window.search.set_text("")

    def tearDown(self):
        self.pump()
        self.assertEqual(self.callback_errors, [], "GTK callback raised an exception")

    def drag(self, widget, value):
        from gi.repository import Gtk
        scroll = widget.get_ancestor(Gtk.ScrolledWindow)
        adjustment = scroll.get_vadjustment()
        adjustment.set_value(adjustment.get_upper() - adjustment.get_page_size())
        self.pump(0.05)
        x, y = widget.translate_coordinates(self.window, 0, 0)
        _, root_x, root_y = self.window.get_window().get_origin()
        area = widget.get_range_rect()
        start, end = widget.get_slider_range()
        half = (end - start) / 2
        bounds = widget.get_adjustment()
        ratio = (value - bounds.get_lower()) / (bounds.get_upper() - bounds.get_lower())
        target = area.x + half + ratio * (area.width - 2 * half)
        def mouse(*args):
            subprocess.run(["xdotool", *map(str, args)], check=True, capture_output=True, timeout=5)
            self.pump(0.04)
        mouse("mousemove", round(root_x + x + (start + end) / 2), round(root_y + y + area.y + area.height / 2))
        mouse("mousedown", 1)
        try:
            mouse("mousemove", round(root_x + x + target), round(root_y + y + area.y + area.height / 2))
        finally:
            mouse("mouseup", 1)
        self.pump(0.5)

    @staticmethod
    def widgets(root):
        yield root
        if hasattr(root, "get_children"):
            for child in root.get_children():
                yield from GuiTests.widgets(child)

    def buttons(self, page, text):
        from gi.repository import Gtk
        return [widget for widget in self.widgets(self.window.pages[page])
                if isinstance(widget, Gtk.Button) and widget.get_label() == text]

    def test_sidebar_brand_is_removed(self):
        from gi.repository import Gtk
        self.assertFalse(any(widget.get_text() in ("BLIX", "Settings") for widget in self.widgets(self.window)
                             if isinstance(widget, Gtk.Label)))

    def test_transparency_applies_immediately_without_discarding_monitor_edits(self):
        self.page("display")
        self.assertTrue(self.window.transparency_switch.get_active())
        self.window.display_controls["eDP-1"]["x"].set_value(80)
        self.window.transparency_switch.set_active(False)
        self.assertFalse(self.window.transparency_switch.get_sensitive())
        self.pump()
        self.assertFalse(self.window.demo.transparency)
        self.assertFalse(self.window.preferences.read()["transparency"])
        self.window.refresh()
        self.pump()
        self.assertEqual(self.window.display_controls["eDP-1"]["x"].get_value(), 80)
        self.assertTrue(self.window.display_apply.get_sensitive())
        self.window.transparency_switch.set_active(True)
        self.pump()
        self.assertTrue(self.window.demo.transparency)
        self.assertNotIn("transparency", self.window.preferences.read())
        self.assertFalse(self.window.demo.calls)
        self.window.search.set_text("transparency")
        self.pump()
        self.assertEqual(self.window.sidebar.get_selected_row().page_name, "display")

    def test_brightness_is_live_wide_and_survives_slider_and_layout_edits(self):
        self.page("display")
        scale = self.window.brightness_slider
        self.assertGreaterEqual(scale.get_allocated_width(), 300)
        self.assertEqual(scale.emit("format-value", 100), "100%")
        self.assertEqual(scale.get_value(), 70)
        self.window.demo.brightness_percent = 100
        self.window.refresh()
        self.pump()
        self.assertEqual(scale.get_value(), 100)
        versions = self.window.slider_versions.copy()
        stale = self.window.demo.snapshot("display")
        scale.set_value(45)
        self.window.update_display(stale, versions)
        self.assertEqual(scale.get_value(), 45)
        self.pump(0.6)
        self.assertEqual(self.window.demo.brightness_percent, 45)
        self.window.display_controls["eDP-1"]["x"].set_value(100)
        self.window.demo.brightness_percent = 85
        self.window.refresh()
        self.pump()
        self.assertEqual(self.window.brightness_slider.get_value(), 85)
        self.assertEqual(self.window.display_controls["eDP-1"]["x"].get_value(), 100)
        self.assertEqual(self.window.text_size.get_text(), "125% (120 DPI)")

    def test_all_four_slider_types_respond_to_real_mouse_drags(self):
        self.page("display")
        self.drag(self.window.brightness_slider, 25)
        self.assertAlmostEqual(self.window.brightness_slider.get_value(), 25, delta=2)
        self.assertEqual(round(self.window.brightness_slider.get_value()), self.window.demo.brightness_percent)
        self.page("audio")
        for kind, plural in (("sink", "sinks"), ("source", "sources")):
            widget = self.window.controls[kind]["volume"]
            self.drag(widget, 30)
            self.assertAlmostEqual(widget.get_value(), 30, delta=2)
            self.assertEqual(round(widget.get_value()), self.window.demo.audio[plural][0]["volume"])
        self.page("input")
        device, controls = self.window.input_controls["touchpad"]
        self.drag(controls["speed"], 0.35)
        self.assertAlmostEqual(controls["speed"].get_value(), 0.35, delta=0.06)
        chosen = controls["speed"].get_value()
        self.window.save_input(device, False)
        self.pump()
        self.assertAlmostEqual(self.window.demo.devices[0]["speed"], chosen)
        self.assertAlmostEqual(self.window.input_controls["touchpad"][1]["speed"].get_value(), chosen)

    def test_display_apply_buttons_track_dirty_and_confirmation_state(self):
        from gi.repository import Gtk
        self.page("display")
        self.assertFalse(self.window.display_apply.get_sensitive())
        self.window.display_controls["eDP-1"]["x"].set_value(80)
        self.assertTrue(self.window.display_apply.get_sensitive())
        self.window.apply_display(False)
        self.assertFalse(self.window.display_apply.get_sensitive())
        self.assertFalse(self.window.display_restore.get_sensitive())
        self.window.dialogs[-1].response(Gtk.ResponseType.OK)
        self.pump()
        self.assertEqual(self.window.demo.monitors[0]["x"], 80)
        self.assertFalse(self.window.display_apply.get_sensitive())
        self.assertTrue(self.window.display_restore.get_sensitive())

    def test_layout_reflects_outputs_instead_of_a_saved_preference(self):
        self.window.preferences.update("display", {"layout": "mirror"})
        self.page("display")
        self.assertEqual(self.window.display_layout.get_active_id(), "extend")
        self.window.demo.monitors[1]["x"] = 0
        self.window.refresh()
        self.pump()
        self.assertEqual(self.window.display_layout.get_active_id(), "mirror")

    def test_live_keyboard_and_timeout_ignore_old_saved_values(self):
        self.window.demo.keyboard = {"delay": 275, "rate": 42}
        self.window.demo.blank_seconds = 90
        self.window.preferences.update("keyboard", {"delay": 600, "rate": 20})
        self.window.preferences.update("blank_seconds", 600)
        self.page("input")
        self.assertEqual(self.window.repeat_delay.get_value(), 275)
        self.assertEqual(self.window.repeat_rate.get_value(), 42)
        self.page("power")
        self.assertEqual(self.window.blank_minutes.get_value(), 1.5)
        self.window.blank_minutes.set_value(2)
        self.window.demo.blank_seconds = 30
        self.window.refresh()
        self.pump()
        self.assertEqual(self.window.blank_minutes.get_value(), 2)
        self.window.save_blank()
        self.pump()
        self.assertEqual(self.window.demo.blank_seconds, 120)

    def test_input_hotplug_preserves_other_unsaved_controls(self):
        self.page("input")
        device, controls = self.window.input_controls["touchpad"]
        controls["speed"].set_value(0.35)
        controls["natural"].set_active(False)
        self.window.repeat_delay.set_value(450)
        self.window.demo.devices.append({"id": "13", "name": "Mouse", "key": "mouse", "touchpad": False,
                                         "speed": -0.2, "natural": True, "tapping": None})
        self.window.refresh()
        self.pump()
        controls = self.window.input_controls["touchpad"][1]
        self.assertAlmostEqual(controls["speed"].get_value(), 0.35)
        self.assertFalse(controls["natural"].get_active())
        self.assertEqual(self.window.repeat_delay.get_value(), 450)
        self.window.save_input(device, False)
        self.pump()
        self.assertAlmostEqual(self.window.demo.devices[0]["speed"], 0.35)
        self.assertEqual(self.window.demo.devices[1]["speed"], -0.2)

    def test_audio_reports_boosted_volume_and_disables_missing_devices(self):
        self.window.demo.audio["sinks"][0]["volume"] = 125
        self.page("audio")
        self.assertEqual(self.window.controls["sink"]["volume"].get_value(), 125)
        self.window.toggle_meter()
        self.assertEqual(self.window.meter_button.get_label(), "Stop microphone test")
        self.window.toggle_meter()
        self.assertEqual(self.window.meter_button.get_label(), "Test microphone")
        self.window.demo.audio.update(sinks=[], sources=[], sink=None, source=None)
        self.window.refresh()
        self.pump()
        self.assertFalse(self.window.sound_button.get_sensitive())
        self.assertFalse(self.window.meter_button.get_sensitive())
        for kind in ("sink", "source"):
            self.assertTrue(all(not widget.get_sensitive() for widget in self.window.controls[kind].values()))

    def test_wifi_disconnect_uses_active_uuid_and_tracks_pending_and_failed_actions(self):
        item = self.window.demo.wifi["networks"][0]
        item.update(saved="another-profile", active_uuid="actual-active-profile")
        self.window.demo.wifi["profiles"][0]["uuid"] = "actual-active-profile"
        self.page("network")
        self.assertTrue(self.buttons("network", "Disconnect"))
        callbacks = []
        with patch.object(self.window.network, "disconnect", side_effect=lambda uuid, done: callbacks.append(done)) as disconnect:
            self.window.connect_wifi(item)
            disconnect.assert_called_once()
            self.assertEqual(disconnect.call_args.args[0], "actual-active-profile")
            busy = self.buttons("network", "Disconnecting…")
            self.assertEqual(len(busy), 2)
            self.assertTrue(all(not widget.get_sensitive() for widget in busy))
        callbacks[0]("Disconnect failed")
        self.pump()
        self.assertTrue(self.buttons("network", "Disconnect"))
        self.assertFalse(self.buttons("network", "Disconnecting…"))

    def test_network_and_bluetooth_buttons_follow_hardware_and_discovery_state(self):
        self.window.demo.wifi["enabled"] = self.window.demo.wifi["available"] = False
        for item in self.window.demo.wifi["networks"] + self.window.demo.wifi["profiles"]:
            item["active"] = False
        self.page("network")
        self.assertFalse(self.buttons("network", "Scan for networks")[0].get_sensitive())
        self.assertTrue(all(not widget.get_sensitive() for widget in self.buttons("network", "Connect")))
        adapter = self.window.demo.bluetooth["adapters"][0]
        adapter["powered"] = False
        self.page("bluetooth")
        self.assertFalse(self.buttons("bluetooth", "Pair")[0].get_sensitive())
        adapter.update(powered=True, discovering=True, scanning=False)
        self.window.refresh()
        self.pump()
        self.assertTrue(self.buttons("bluetooth", "Join discovery"))
        self.window.scan_bluetooth(adapter, False)
        self.assertTrue(self.buttons("bluetooth", "Stop discovery"))

    def test_toggles_keep_the_requested_value_when_radio_pages_rebuild(self):
        from gi.repository import Gtk
        self.window.demo.wifi["enabled"] = False
        self.page("network")
        toggle = next(widget for widget in self.widgets(self.window.pages["network"]) if isinstance(widget, Gtk.Switch))
        toggle.set_active(True)
        self.pump()
        self.assertTrue(self.window.demo.wifi["enabled"])
        self.assertEqual([call for call in self.window.demo.calls if call[:2] == ("network", "toggle")], [("network", "toggle", True)])
        adapter = self.window.demo.bluetooth["adapters"][0]
        adapter["powered"] = False
        self.page("bluetooth")
        toggle = next(widget for widget in self.widgets(self.window.pages["bluetooth"]) if isinstance(widget, Gtk.Switch))
        toggle.set_active(True)
        self.pump()
        self.assertTrue(adapter["powered"])

    def test_prepopulation_and_disposal_never_issue_setting_commands(self):
        for page in ("display", "audio", "input", "power", "display", "input", "audio"):
            self.window.invalidate(page)
            self.page(page)
        self.assertEqual(self.window.demo.calls, [])
        self.assertFalse(self.window.dirty_display)
        self.assertFalse(self.window.dirty_keyboard)
        self.assertFalse(self.window.dirty_blank)
        self.assertFalse(self.window.dirty_inputs)

    def test_slider_writes_are_serialized_and_keep_the_latest_drag_value(self):
        self.page("display")
        for wait_for_timer in (True, False):
            with self.subTest(wait_for_timer=wait_for_timer):
                started, release = threading.Event(), threading.Event()
                original = self.window.command
                calls = []
                def slow(name, *args):
                    if name == "brightnessctl":
                        calls.append(args[-1])
                        if len(calls) == 1:
                            started.set()
                            release.wait(3)
                    return original(name, *args)
                with patch.object(self.window, "command", side_effect=slow):
                    self.window.brightness_slider.set_value(30)
                    self.pump(0.3)
                    self.assertTrue(started.is_set())
                    self.window.brightness_slider.set_value(55)
                    if wait_for_timer:
                        self.pump(0.3)
                    self.assertEqual(calls, ["30%"])
                    release.set()
                    self.pump(0.6)
                self.assertEqual(calls, ["30%", "55%"])
                self.assertEqual(self.window.demo.brightness_percent, 55)

    def test_every_page_and_search_render(self):
        from ui import PAGES
        for name, *_ in PAGES:
            self.page(name)
            self.assertEqual(self.window.stack.get_visible_child_name(), name)
            self.assertTrue(self.window.pages[name].get_children())
        self.window.search.set_text("microphone")
        self.pump()
        self.assertEqual(self.window.page, "audio")
        self.window.search.set_text("")
        self.pump()

    def test_about_refresh_keeps_current_system_details_visible(self):
        from gi.repository import Gtk
        self.page("about")
        values = [("Device", "Live host"), ("Kernel", "Updated kernel")]
        self.window.build_about(values)
        self.pump()
        labels = [widget for widget in self.widgets(self.window.pages["about"]) if isinstance(widget, Gtk.Label)]
        for text in ("Live host", "Updated kernel"):
            widget = next(widget for widget in labels if widget.get_text() == text)
            self.assertTrue(widget.get_visible())
            self.assertTrue(widget.get_mapped())

    def test_audio_and_persisted_input_actions(self):
        self.page("audio")
        self.window.controls["sink"]["device"].set_active_id("headphones")
        self.pump()
        self.window.controls["sink"]["volume"].set_value(25)
        self.pump(0.5)
        self.assertEqual(self.window.demo.audio["sink"], "headphones")
        self.assertEqual(self.window.demo.audio["sinks"][1]["volume"], 25)
        self.page("input")
        self.window.repeat_delay.set_value(350)
        self.window.save_keyboard()
        self.pump()
        self.assertEqual(self.window.preferences.read()["keyboard"]["delay"], 350)
        self.window.blank_minutes.set_value(5)
        self.window.save_blank()
        self.pump()
        self.assertEqual(self.window.preferences.read()["blank_seconds"], 300)

    def test_wifi_password_cancel_and_connect_do_not_log_password(self):
        from gi.repository import Gtk
        self.page("network")
        guest = self.window.demo.wifi["networks"][1]
        self.window.connect_wifi(guest)
        self.assertTrue(self.window.dialogs)
        self.window.dialogs[-1].response(Gtk.ResponseType.CANCEL)
        self.assertFalse(any(call[:2] == ("network", "connect") for call in self.window.demo.calls))
        self.window.connect_wifi(guest)
        dialog = self.window.dialogs[-1]
        entry = next(widget for widget in dialog.get_content_area().get_children() if isinstance(widget, Gtk.Entry))
        entry.set_text("secret-do-not-log")
        dialog.response(Gtk.ResponseType.OK)
        self.pump()
        self.assertTrue(guest["active"])
        self.assertNotIn("secret-do-not-log", repr(self.window.demo.calls))
        self.assertNotIn("secret-do-not-log", repr(self.window.preferences.read()))

    def test_radio_updates_do_not_start_an_idle_poll_loop(self):
        self.page("network")
        with patch.object(self.window, "refresh", return_value=True) as refresh:
            self.window.radio_changed()
            self.pump(0.1)
            refresh.assert_called_once_with()

    def test_packaged_launcher_focuses_the_existing_window(self):
        executable = source.parent.parent / "bin/blix-settings"
        process = subprocess.Popen([str(executable), "--demo"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        deadline = time.monotonic() + 5
        while process.poll() is None and time.monotonic() < deadline:
            self.pump(0.05)
        try:
            stdout, stderr = process.communicate(timeout=2)
            self.assertEqual(process.returncode, 0, stderr.decode())
            self.assertEqual(len(self.app.get_windows()), 1)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)
