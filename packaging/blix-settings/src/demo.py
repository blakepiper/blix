"""In-memory preview devices, also used by the GTK interaction checks."""
import copy

from core import parse_outputs, default_display


class DemoPreferences:
    def __init__(self):
        self.state = {}

    def read(self):
        return copy.deepcopy(self.state)

    def update(self, key, value):
        if value is None:
            self.state.pop(key, None)
        else:
            self.state[key] = copy.deepcopy(value)


class Demo:
    def __init__(self):
        self.calls = []
        self.defaults = {"capabilities": {"hasBacklight": True, "hasBattery": True, "hasBluetooth": True},
                         "display": {"primaryOutput": "eDP-1", "layout": "extend", "primaryRotation": "normal",
                                     "blankAfterSeconds": 0}, "keyboard": {"delay": 200, "rate": 50},
                         "input": {"mouse": {"speed": 0, "natural": True},
                                   "touchpad": {"speed": 0, "natural": True, "tapping": True}}}
        self.monitors = parse_outputs("""eDP-1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis)
   1920x1080 60.00*+ 120.00
   1280x720 60.00
HDMI-2 connected 1920x1080+1920+0 (normal left inverted right x axis y axis)
   1920x1080 60.00*+ 144.00
   1280x720 60.00
""")
        self.audio = {"sinks": [{"name": "speakers", "description": "Built-in speakers", "volume": 65, "mute": False},
                                {"name": "headphones", "description": "Studio headphones", "volume": 40, "mute": False}],
                      "sources": [{"name": "microphone", "description": "Built-in microphone", "volume": 70, "mute": False}],
                      "sink": "speakers", "source": "microphone"}
        self.devices = [{"id": "12", "name": "Precision touchpad", "key": "touchpad", "touchpad": True,
                         "speed": 0.0, "natural": True, "tapping": True}]
        self.wifi = {"enabled": True, "available": True,
                     "networks": [{"name": "Home", "ssid": b"Home", "security": "wpa", "strength": 94,
                                   "saved": "home", "active": True, "status": "Connected", "device": "wifi", "path": "home"},
                                  {"name": "Guest", "ssid": b"Guest", "security": "wpa", "strength": 72,
                                   "saved": None, "active": False, "status": "Disconnected", "device": "wifi", "path": "guest"}],
                     "wired": [{"name": "Ethernet", "status": "Disconnected", "address": ""}],
                     "profiles": [{"name": "Home", "uuid": "home", "type": "802-11-wireless", "active": True}]}
        self.bluetooth = {"adapters": [{"path": "adapter", "name": "Bluetooth", "powered": True, "discovering": False}],
                          "devices": [{"path": "headphones", "name": "Studio headphones", "adapter": "adapter",
                                       "paired": True, "connected": True, "trusted": True},
                                      {"path": "keyboard", "name": "Wireless keyboard", "adapter": "adapter",
                                       "paired": False, "connected": False, "trusted": False}]}

    def command(self, name, *args):
        self.calls.append((name, *args))
        if name == "pactl":
            operation = args[0]
            if operation in ("set-default-sink", "set-default-source"):
                self.audio["sink" if operation.endswith("sink") else "source"] = args[1]
            elif operation.startswith("set-"):
                kind = "sinks" if "sink" in operation else "sources"
                device = next(item for item in self.audio[kind] if item["name"] == args[1])
                if "volume" in operation:
                    device["volume"] = int(str(args[2]).rstrip("%"))
                else:
                    device["mute"] = bool(int(args[2]))
        return ""

    def snapshot(self, kind):
        return copy.deepcopy({"display": self.monitors, "audio": self.audio, "input": self.devices,
                              "network": self.wifi, "bluetooth": self.bluetooth}[kind])

    def display_default(self):
        return default_display(self.monitors, self.defaults["display"])


class DemoRadio:
    def __init__(self, demo, kind):
        self.demo, self.kind = demo, kind

    def snapshot(self):
        return self.demo.snapshot(self.kind)

    def toggle(self, *args):
        self.demo.calls.append((self.kind, "toggle", *args))
        if self.kind == "network":
            self.demo.wifi["enabled"] = args[0]
        else:
            self.demo.bluetooth["adapters"][0]["powered"] = args[1]

    def scan(self, *args):
        self.demo.calls.append((self.kind, "scan"))
        if self.kind == "network":
            args[0](None)

    def stop_scan(self):
        pass

    def connect_network(self, item, password, callback):
        # Never store the submitted password, including in the preview log.
        self.demo.calls.append(("network", "connect", item["name"]))
        for network in self.demo.wifi["networks"]:
            network["active"] = network["name"] == item["name"]
        callback(None)

    def activate(self, value, callback):
        self.demo.calls.append(("network", "activate", value))
        callback(None)

    def disconnect(self, value, callback):
        self.demo.calls.append(("network", "disconnect", value))
        callback(None)

    def forget(self, value, callback):
        self.demo.calls.append(("network", "forget", value))
        self.demo.wifi["profiles"] = [item for item in self.demo.wifi["profiles"] if item["uuid"] != value]
        callback(None)

    def action(self, item, action, callback):
        self.demo.calls.append(("bluetooth", action, item["name"]))
        device = next(value for value in self.demo.bluetooth["devices"] if value["path"] == item["path"])
        if action == "Pair":
            device["paired"] = device["trusted"] = True
        elif action == "RemoveDevice":
            self.demo.bluetooth["devices"].remove(device)
        else:
            device["connected"] = action == "Connect"
        callback(None)

    def close(self):
        pass
