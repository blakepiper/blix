"""Exercise the packaged reconnect loop without a radio or desktop session."""
import ast
from pathlib import Path
from types import SimpleNamespace
from typing import Optional, Union
import sys
import unittest
from unittest.mock import Mock


class Device(dict):
    display_name = "Keyboard"

    def get_object_path(self):
        return "/test/keyboard"


tree = ast.parse(Path(sys.argv.pop(1)).read_text())
plugin = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "AutoConnect")
method = next(node for node in plugin.body if isinstance(node, ast.FunctionDef) and node.name == "_run")
notification = Mock()
namespace = {
    "Device": Device, "Optional": Optional, "Union": Union,
    "ServiceUUID": lambda _: SimpleNamespace(name="Input"),
    "Notification": notification, "_": lambda value: value,
}
exec(compile(ast.Module(body=[method], type_ignores=[]), "AutoConnect.py", "exec"), namespace)


class AutoConnectTest(unittest.TestCase):
    def run_plugin(self, *, connected=False, missing=False, notify=False, fail=False, services=True):
        notification.reset_mock()
        device = Device(Connected=connected, Icon="input-keyboard")
        connect = Mock(side_effect=lambda path, uuid, ok, err: err("unavailable") if fail else ok())
        parent = SimpleNamespace(
            Manager=SimpleNamespace(find_device=Mock(return_value=None if missing else device)),
            Plugins=SimpleNamespace(DBusService=SimpleNamespace(connect_service=connect),
                                    get_loaded=lambda: ["ConnectionNotifier"] if notify else []),
        )
        instance = SimpleNamespace(parent=parent, get_option=lambda _: [("paired-keyboard", "generic")] if services else [])
        self.assertTrue(namespace["_run"](instance))
        return connect

    def test_reconnect_without_popup(self):
        connect = self.run_plugin()
        self.assertEqual(connect.call_args.args[:2], ("/test/keyboard", "generic"))
        connect.assert_called_once()
        notification.assert_not_called()

    def test_notification_when_enabled(self):
        self.run_plugin(notify=True).assert_called_once()
        notification.return_value.show.assert_called_once()

    def test_connected_or_missing_device_is_skipped(self):
        for args in ({"connected": True}, {"missing": True}, {"services": False}):
            with self.subTest(**args):
                self.run_plugin(**args).assert_not_called()
                notification.assert_not_called()

    def test_failed_connection_does_not_notify_or_stop_retries(self):
        self.run_plugin(fail=True, notify=True).assert_called_once()
        notification.assert_not_called()


if __name__ == "__main__":
    unittest.main()
