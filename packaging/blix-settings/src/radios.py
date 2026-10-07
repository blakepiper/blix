"""NetworkManager/libnm and BlueZ controls on the GTK main context."""
import os
import pwd
import uuid

import gi
gi.require_version("NM", "1.0")
from gi.repository import GLib, NM
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop

from core import SettingsError


def wifi_security(flags, wpa, rsn):
    # NM80211ApSecurityFlags from libnm's public enum; these are protocol bits.
    security = int(wpa) | int(rsn)
    if security & 0x200:
        return "enterprise"
    if security & 0x400:
        return "sae"
    if security & (0x800 | 0x1000):
        return "owe"
    if security & 0x100:
        return "wpa"
    return "wep" if int(flags) & 1 else "open"


def wifi_connection(ssid, security, password=None):
    """Construct a user-owned profile; passwords go only to NetworkManager."""
    if security in ("enterprise", "wep"):
        raise SettingsError("Use Advanced Connections to configure this network's authentication.")
    if security in ("wpa", "sae") and not password:
        raise SettingsError("Enter the Wi-Fi password.")
    connection = NM.SimpleConnection.new()
    identity = NM.SettingConnection.new()
    identity.props.id = ssid.decode("utf-8", errors="replace")
    identity.props.uuid = str(uuid.uuid4())
    identity.props.type = "802-11-wireless"
    identity.props.autoconnect = True
    identity.add_permission("user", pwd.getpwuid(os.getuid()).pw_name, None)
    wireless = NM.SettingWireless.new()
    wireless.props.ssid = GLib.Bytes.new(ssid)
    wireless.props.mode = "infrastructure"
    connection.add_setting(identity)
    connection.add_setting(wireless)
    if security != "open":
        authentication = NM.SettingWirelessSecurity.new()
        authentication.props.key_mgmt = {"wpa": "wpa-psk", "sae": "sae", "owe": "owe"}[security]
        if password:
            authentication.props.psk = password
            authentication.props.psk_flags = NM.SettingSecretFlags.NONE
        connection.add_setting(authentication)
    for setting in (NM.SettingIP4Config.new(), NM.SettingIP6Config.new()):
        setting.props.method = "auto"
        connection.add_setting(setting)
    connection.verify()
    return connection


class Network:
    def __init__(self, changed):
        self.client = NM.Client.new(None)
        self.changed = changed
        self.client.connect("notify", lambda *_: changed())

    def snapshot(self):
        if not self.client.get_nm_running():
            raise SettingsError("NetworkManager is not running.")
        networks, wired = {}, []
        devices = self.client.get_devices()
        active_connections = {connection.get_uuid(): connection for connection in self.client.get_active_connections()}
        for device in devices:
            state = device.get_state()
            status = state.value_nick.replace("-", " ").capitalize()
            if state == NM.DeviceState.ACTIVATED:
                status = "Connected"
            if device.get_device_type() == NM.DeviceType.ETHERNET:
                addresses = device.get_ip4_config()
                address = ", ".join(item.get_address() for item in addresses.get_addresses()) if addresses else ""
                wired.append({"name": device.get_iface(), "status": status, "address": address})
            if device.get_device_type() != NM.DeviceType.WIFI:
                continue
            active = device.get_active_access_point()
            connection = device.get_active_connection()
            points = list(device.get_access_points())
            if active and all(ap.get_path() != active.get_path() for ap in points):
                points.insert(0, active)
            for ap in points:
                raw = ap.get_ssid()
                if not raw:
                    continue
                ssid = bytes(raw.get_data())
                security = wifi_security(ap.get_flags(), ap.get_wpa_flags(), ap.get_rsn_flags())
                key = (ssid, security, device.get_path())
                saved = next((profile for profile in device.get_available_connections()
                              if profile.get_setting_wireless() and profile.get_setting_wireless().get_ssid()
                              and bytes(profile.get_setting_wireless().get_ssid().get_data()) == ssid
                              and ap.connection_valid(profile)), None)
                item = {"ssid": ssid, "name": ssid.decode("utf-8", errors="replace"), "security": security,
                        "strength": ap.get_strength(), "path": ap.get_path(), "device": device.get_path(),
                        "saved": saved.get_uuid() if saved else None,
                        "active": bool(active and active.get_path() == ap.get_path() and state == NM.DeviceState.ACTIVATED),
                        "connecting": bool(active and active.get_path() == ap.get_path() and
                                           NM.DeviceState.PREPARE <= state < NM.DeviceState.ACTIVATED),
                        "disconnecting": bool(active and active.get_path() == ap.get_path() and state == NM.DeviceState.DEACTIVATING),
                        "active_uuid": connection.get_uuid() if connection and active and active.get_path() == ap.get_path() else None,
                        "status": status}
                # The active AP wins even when another BSSID for this SSID is
                # stronger. Keep its signal and connection state together.
                def rank(value):
                    return (value["active"], value["connecting"], value["disconnecting"], value["strength"])
                if key not in networks or rank(item) > rank(networks[key]):
                    networks[key] = item
        available = {profile.get_uuid() for device in devices for profile in device.get_available_connections()}
        profiles = []
        for profile in self.client.get_connections():
            kind, uuid_value = profile.get_connection_type(), profile.get_uuid()
            if kind == "loopback":
                continue
            active = active_connections.get(uuid_value)
            state = active.get_state() if active else NM.ActiveConnectionState.DEACTIVATED
            profiles.append({"name": profile.get_id(), "uuid": uuid_value, "type": kind,
                "active": state == NM.ActiveConnectionState.ACTIVATED,
                "connecting": state == NM.ActiveConnectionState.ACTIVATING,
                "disconnecting": state == NM.ActiveConnectionState.DEACTIVATING,
                "available": uuid_value in available or kind not in ("802-11-wireless", "802-3-ethernet")})
        return {"enabled": self.client.wireless_get_enabled(), "has_adapter": any(device.get_device_type() == NM.DeviceType.WIFI for device in devices),
                "available": self.client.wireless_hardware_get_enabled()
                and any(device.get_device_type() == NM.DeviceType.WIFI for device in devices),
                "networks": sorted(networks.values(), key=lambda item: (not item["active"], -item["strength"], item["name"])),
                "wired": wired, "profiles": sorted(profiles, key=lambda item: item["name"].lower())}

    def toggle(self, enabled):
        self.client.wireless_set_enabled(enabled)

    def scan(self, callback):
        devices = [device for device in self.client.get_devices() if device.get_device_type() == NM.DeviceType.WIFI]
        if not devices:
            raise SettingsError("No Wi-Fi adapter was found.")
        def finished(device, result, _):
            try:
                device.request_scan_finish(result)
                callback(None)
            except GLib.Error as error:
                callback(str(error))
        for device in devices:
            device.request_scan_async(None, finished, None)

    def connect_network(self, item, password, callback):
        device = self.client.get_device_by_path(item["device"])
        if not device:
            raise SettingsError("The Wi-Fi adapter is no longer available.")
        if item.get("saved"):
            self.activate(item["saved"], callback, device, item["path"])
            return
        profile = wifi_connection(item["ssid"], item["security"], password)
        def finished(client, result, _):
            try:
                client.add_and_activate_connection_finish(result)
                callback(None)
            except GLib.Error as error:
                callback(str(error))
        self.client.add_and_activate_connection_async(profile, device, item["path"], None, finished, None)

    def activate(self, uuid_value, callback, device=None, specific=None):
        profile = self.client.get_connection_by_uuid(uuid_value)
        if not profile:
            raise SettingsError("This saved connection is no longer available.")
        def finished(client, result, _):
            try:
                client.activate_connection_finish(result)
                callback(None)
            except GLib.Error as error:
                callback(str(error))
        self.client.activate_connection_async(profile, device, specific, None, finished, None)

    def disconnect(self, uuid_value, callback):
        active = next((item for item in self.client.get_active_connections() if item.get_uuid() == uuid_value), None)
        if not active:
            callback(None)
            return
        def finished(client, result, _):
            try:
                client.deactivate_connection_finish(result)
                callback(None)
            except GLib.Error as error:
                callback(str(error))
        self.client.deactivate_connection_async(active, None, finished, None)

    def forget(self, uuid_value, callback):
        profile = self.client.get_connection_by_uuid(uuid_value)
        if not profile:
            raise SettingsError("This saved connection is no longer available.")
        def finished(connection, result, _):
            try:
                connection.delete_finish(result)
                callback(None)
            except GLib.Error as error:
                callback(str(error))
        profile.delete_async(None, finished, None)


class PairingAgent(dbus.service.Object):
    def __init__(self, bus, prompt, notify):
        super().__init__(bus, "/org/blix/Settings/agent")
        self.prompt = prompt
        self.notify = notify
        self.cancel_prompt = None

    def ask(self, device, message, reply, error, kind):
        def answered(value):
            self.cancel_prompt = None
            if value is None:
                error(dbus.exceptions.DBusException("Pairing canceled.", name="org.bluez.Error.Rejected"))
            elif kind == "confirm":
                reply()
            elif kind == "passkey":
                if not str(value).isdigit() or not 0 <= int(value) <= 999999:
                    error(dbus.exceptions.DBusException("Enter a six-digit passkey.", name="org.bluez.Error.Rejected"))
                else:
                    reply(dbus.UInt32(int(value)))
            else:
                if not 1 <= len(value) <= 16:
                    error(dbus.exceptions.DBusException("The PIN must contain 1–16 characters.", name="org.bluez.Error.Rejected"))
                else:
                    reply(value)
        self.cancel_prompt = self.prompt("Bluetooth pairing", message, kind != "confirm", answered)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s", async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        self.ask(device, "Enter the PIN shown on your Bluetooth device.", reply, error, "pin")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u", async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        self.ask(device, "Enter the six-digit passkey shown on your Bluetooth device.", reply, error, "passkey")

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="", async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        self.ask(device, f"Does your device show {int(passkey):06d}?", reply, error, "confirm")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="", async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        self.ask(device, "Allow this device to pair?", reply, error, "confirm")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="", async_callbacks=("reply", "error"))
    def AuthorizeService(self, device, uuid_value, reply, error):
        self.ask(device, "Allow this paired device to use a Bluetooth service?", reply, error, "confirm")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pin):
        self.notify(f"Type PIN {pin} on your Bluetooth device, then press Enter.")

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        self.notify(f"Type {int(passkey):06d} on your Bluetooth device, then press Enter. ({entered}/6)")

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        if self.cancel_prompt:
            self.cancel_prompt()
            self.cancel_prompt = None

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        self.Cancel()


class Bluetooth:
    def __init__(self, changed, prompt, notify):
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        self.changed, self.notify = changed, notify
        self.agent = PairingAgent(self.bus, prompt, notify)
        self.scanning = None
        try:
            self.manager = dbus.Interface(self.bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
            self.manager.RegisterAgent(self.agent.__dbus_object_path__, "KeyboardDisplay", timeout=3)
        except dbus.DBusException:
            self.agent.remove_from_connection()
            raise
        # Keep Blueman's session agent as the default for other applications.
        self.matches = [self.bus.add_signal_receiver(lambda *_: changed(), signal_name=signal,
            dbus_interface=interface, bus_name="org.bluez") for signal, interface in (
                ("InterfacesAdded", "org.freedesktop.DBus.ObjectManager"),
                ("InterfacesRemoved", "org.freedesktop.DBus.ObjectManager"),
                ("PropertiesChanged", "org.freedesktop.DBus.Properties"))]

    def snapshot(self):
        manager = dbus.Interface(self.bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
        adapters, devices = [], []
        for path, interfaces in manager.GetManagedObjects(timeout=3).items():
            adapter = interfaces.get("org.bluez.Adapter1")
            device = interfaces.get("org.bluez.Device1")
            if adapter:
                adapters.append({"path": str(path), "name": str(adapter.get("Alias", "Bluetooth")),
                                 "powered": bool(adapter.get("Powered")), "discovering": bool(adapter.get("Discovering")),
                                 "scanning": self.scanning == str(path) and bool(adapter.get("Discovering"))})
            if device:
                devices.append({"path": str(path), "name": str(device.get("Alias", device.get("Address", "Bluetooth device"))),
                                "adapter": str(device.get("Adapter")), "paired": bool(device.get("Paired")),
                                "connected": bool(device.get("Connected")), "trusted": bool(device.get("Trusted"))})
        return {"adapters": adapters, "devices": sorted(devices, key=lambda item: (not item["connected"], not item["paired"], item["name"].lower()))}

    def interface(self, path, name):
        return dbus.Interface(self.bus.get_object("org.bluez", path), name)

    def toggle(self, path, powered):
        self.interface(path, "org.freedesktop.DBus.Properties").Set("org.bluez.Adapter1", "Powered", dbus.Boolean(powered), timeout=3)

    def scan(self, path):
        if self.scanning:
            self.stop_scan()
        self.interface(path, "org.bluez.Adapter1").StartDiscovery(timeout=3)
        self.scanning = path
        GLib.timeout_add_seconds(30, self.stop_scan)

    def stop_scan(self):
        if self.scanning:
            path, self.scanning = self.scanning, None
            try:
                self.interface(path, "org.bluez.Adapter1").StopDiscovery(timeout=3)
            except dbus.DBusException:
                pass
        return False

    def action(self, item, action, callback):
        def finished(*_):
            self.changed()
            if action == "Pair":
                try:
                    self.interface(item["path"], "org.freedesktop.DBus.Properties").Set(
                        "org.bluez.Device1", "Trusted", dbus.Boolean(True), timeout=3)
                except dbus.DBusException as error:
                    callback(str(error))
                    return
            callback(None)
        def failed(error):
            callback(str(error))
        interface = self.interface(item["adapter"] if action == "RemoveDevice" else item["path"],
                                   "org.bluez.Adapter1" if action == "RemoveDevice" else "org.bluez.Device1")
        method = getattr(interface, action)
        method(*([dbus.ObjectPath(item["path"])] if action == "RemoveDevice" else []),
               reply_handler=finished, error_handler=failed, timeout=90 if action == "Pair" else 15)

    def close(self):
        self.stop_scan()
        self.agent.Cancel()
        for match in self.matches:
            match.remove()
        try:
            self.manager.UnregisterAgent(self.agent.__dbus_object_path__, timeout=3)
        except dbus.DBusException:
            pass
        self.agent.remove_from_connection()
