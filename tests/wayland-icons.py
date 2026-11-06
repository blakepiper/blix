"""Use real GTK/GIO/Qt lookups and notification rules on the isolated bus."""
import os
import configparser
from pathlib import Path
import subprocess
import time

data = Path(os.environ['ICON_DATA'])
os.environ['XDG_DATA_DIRS'] = ':'.join([str(data), os.environ['ICON_MODERN'], os.environ['ICON_FALLBACK'], os.environ.get('XDG_DATA_DIRS', '')])

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gio, GLib, Gtk

source = Path(os.environ['ICON_SOURCE'])
launcher = configparser.ConfigParser()
launcher.read(os.environ['FUZZEL_CONFIG'])
assert launcher['main']['icon-theme'] == 'Blix'
subprocess.run([os.environ['FUZZEL_COMMAND'], '--check-config', '--config', os.environ['FUZZEL_CONFIG']], check=True)
for theme_name in ('Adwaita', 'Blix'):
    theme = Gtk.IconTheme.new()
    theme.set_custom_theme(theme_name)
    for name in ('firefox', 'firefox-esr', 'org.mozilla.firefox'):
        icon = theme.lookup_icon(name, 48, Gtk.IconLookupFlags(0))
        assert icon and Path(icon.get_filename()).is_relative_to(data), (theme_name, name, icon)
    assert theme.lookup_icon('folder', 48, Gtk.IconLookupFlags(0)), 'Other icons must retain their fallback'
assert Gio.DesktopAppInfo.new('firefox.desktop').get_icon().to_string() == str(source)
assert (data / 'icons/Blix/scalable/apps/firefox.svg').read_bytes() == source.read_bytes()
subprocess.run([os.environ['ICON_QT_TEST'], str(data / 'icons/hicolor/48x48/apps/firefox.png'), str(source)],
               env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_QPA_PLATFORMTHEME': ''}, check=True)

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
with Path('icon-notification.log').open('w+') as log:
    process = subprocess.Popen([os.environ['DUNST_COMMAND'], '--print'], stdout=log, stderr=log,
                               env={**os.environ, 'XDG_SESSION_TYPE': 'wayland'})
    try:
        deadline = time.monotonic() + 5
        while not bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                                'NameHasOwner', GLib.Variant('(s)', ('org.freedesktop.Notifications',)),
                                None, Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]:
            assert process.poll() is None, Path('icon-notification.log').read_text()
            assert time.monotonic() < deadline
            time.sleep(0.05)
        bus.call_sync('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                       'org.freedesktop.Notifications', 'Notify',
                       GLib.Variant('(susssasa{sv}i)', ('Firefox', 0, 'firefox', 'Retro icon test', '', [], {}, 1000)),
                       None, Gio.DBusCallFlags.NONE, 5000, None)
        deadline = time.monotonic() + 5
        while f"icon: '{source}'" not in Path('icon-notification.log').read_text():
            assert time.monotonic() < deadline, Path('icon-notification.log').read_text()
            time.sleep(0.05)
    finally:
        process.terminate()
        process.wait(timeout=5)
print('Retro Firefox icon: GTK, GIO desktop entry, Qt, compositor theme and notification rule passed')
