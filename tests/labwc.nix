# Start the generated configuration on a synthetic output; never touch a real seat.
{ lib, pkgs, fixture }:
let
  laptop = fixture { profile = ../profiles/laptop.nix; system = pkgs.stdenv.hostPlatform.system; };
  phone = fixture { profile = ../profiles/phone.nix; system = pkgs.stdenv.hostPlatform.system; };
  home = laptop.config.home-manager.users.przvl;
  rc = pkgs.writeText "blix-labwc-rc.xml" home.xdg.configFile."labwc/rc.xml".text;
  theme = pkgs.writeText "blix-labwc-themerc" home.xdg.configFile."labwc/themerc-override".text;
  wants = home.systemd.user.targets.blix-wayland-session.Unit.Wants;
in
assert laptop.config.programs.labwc.enable;
assert laptop.config.services.xserver.windowManager.oxwm.enable;
assert !phone.config.programs.labwc.enable;
assert !(phone.config.home-manager.users.przvl.systemd.user.targets ? blix-wayland-session);
assert !lib.any (unit: builtins.elem unit wants) [ "blix-session.target" "blix-picom.service" "blix-lock.service" "blix-display-hotplug.service" "blix-nightlight.service" ];
assert builtins.elem "blix-wayland-nightlight.service" wants;
pkgs.runCommand "labwc-session-checks" {
  nativeBuildInputs = [ pkgs.labwc (pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.pycairo ])) pkgs.dbus pkgs.wlr-randr pkgs.wlrctl pkgs.grim ];
  GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" (map lib.getLib [ pkgs.gtk3 pkgs.gtk-layer-shell pkgs.glib pkgs.gobject-introspection pkgs.pango pkgs.harfbuzz pkgs.atk pkgs.gdk-pixbuf ]);
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  SLIDER_SOURCE = ../home/przvl/config/labwc/slider.py;
  SLIDER_TEST = ./wayland-sliders.py;
  PANEL_COMMAND = home.systemd.user.services.blix-wayland-panel.Service.ExecStart;
  PANEL_TEST = ./wayland-panel-anchor.py;
} ''
  export HOME="$TMPDIR/home" XDG_RUNTIME_DIR="$TMPDIR/runtime"
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR" config
  chmod 700 "$XDG_RUNTIME_DIR"
  cp ${rc} config/rc.xml
  cp ${theme} config/themerc-override
  # Exclude session autostart: this check must not interact with a user manager.
  touch config/autostart config/shutdown config/environment
  export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_HEADLESS_OUTPUTS=1
  export XKB_CONFIG_ROOT=${pkgs.xkeyboard_config}/share/X11/xkb
  unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
  dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- python3 ${./labwc.py}
  touch "$out"
''
