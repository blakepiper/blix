{ lib, pkgs }:

let
  app = pkgs.callPackage ../packaging/blix-settings { };
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.pycairo ps.dbus-python ]);
in
pkgs.runCommand "blix-settings-checks" {
  nativeBuildInputs = [ python pkgs.xvfb pkgs.dbus pkgs.xdotool ];
  GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" (map lib.getLib [
    pkgs.gtk3 pkgs.glib pkgs.gobject-introspection pkgs.networkmanager
    pkgs.pango pkgs.harfbuzz pkgs.atk pkgs.gdk-pixbuf
  ]);
  LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.gtk3 pkgs.glib pkgs.networkmanager pkgs.pango pkgs.cairo pkgs.atk pkgs.gdk-pixbuf ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  XDG_DATA_DIRS = "${pkgs.adwaita-icon-theme}/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}";
} ''
  export HOME="$TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config" XDG_RUNTIME_DIR="$TMPDIR/runtime"
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
  dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- python3 ${./blix-settings.py} ${app}/share/blix-settings
  touch "$out"
''
