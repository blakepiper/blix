"""Test commands and failure recovery in isolation; never alter a live session."""
import copy
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

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
        self.pump()

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
