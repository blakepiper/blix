# Start the generated configuration on a synthetic output; never touch a real seat.
{ lib, pkgs, fixture }:
let
  laptop = fixture { profile = ../profiles/laptop.nix; system = pkgs.stdenv.hostPlatform.system; };
  phone = fixture { profile = ../profiles/phone.nix; system = pkgs.stdenv.hostPlatform.system; };
  home = laptop.config.home-manager.users.przvl;
  steamLaptop = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ ../modules/desktop/steam.nix ];
  };
  steamBinding = ''<keybind key="W-g"><action name="Execute" command="${lib.escapeXML "${steamLaptop.config.programs.steam.package}/bin/steam"}" /></keybind>'';
  rc = pkgs.writeText "blix-labwc-rc.xml" home.xdg.configFile."labwc/rc.xml".text;
  theme = pkgs.writeText "blix-labwc-themerc" home.xdg.configFile."labwc/themerc-override".text;
  wants = home.systemd.user.targets.blix-wayland-session.Unit.Wants;
  iconLookup = pkgs.runCommand "blix-qt-icon-lookup" {
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.qt6.qtbase ];
  } ''
    ${pkgs.stdenv.cc}/bin/c++ -fPIC ${./wayland-icon-lookup.cpp} $(pkg-config --cflags --libs Qt6Gui) -o "$out"
  '';
in
assert laptop.config.programs.labwc.enable;
assert pkgs.stdenv.hostPlatform.isx86 ->
  lib.hasInfix (builtins.unsafeDiscardStringContext steamBinding)
    steamLaptop.config.home-manager.users.przvl.xdg.configFile."labwc/rc.xml".text;
assert !(lib.hasInfix ''key="W-g"'' home.xdg.configFile."labwc/rc.xml".text);
assert laptop.config.security.pam.services ? gtklock;
assert !(phone.config.security.pam.services ? gtklock);
assert laptop.config.services.xserver.windowManager.oxwm.enable;
assert !phone.config.programs.labwc.enable;
assert !(phone.config.home-manager.users.przvl.systemd.user.targets ? blix-wayland-session);
assert !lib.any (unit: builtins.elem unit wants) [ "blix-session.target" "blix-picom.service" "blix-lock.service" "blix-display-hotplug.service" "blix-nightlight.service" ];
assert builtins.elem "blix-wayland-nightlight.service" wants;
assert !(builtins.elem "app-com.mitchellh.ghostty.service" wants);
assert builtins.elem "app-com.mitchellh.ghostty.service"
  home.systemd.user.targets.blix-session.Unit.Wants;
pkgs.runCommand "labwc-session-checks" {
  nativeBuildInputs = [ pkgs.labwc (pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.pycairo ])) pkgs.dbus pkgs.wlr-randr pkgs.wlrctl pkgs.grim pkgs.strace ];
  GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" (map lib.getLib [ pkgs.gtk3 pkgs.gtk-layer-shell pkgs.glib pkgs.gobject-introspection pkgs.pango pkgs.harfbuzz pkgs.atk pkgs.gdk-pixbuf ]);
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  LOCK_LAYOUT = home.xdg.configFile."gtklock/layout.ui".source;
  LOCK_STYLE = home.xdg.configFile."gtklock/style.css".source;
  LOCK_CONFIG = home.xdg.configFile."gtklock/config.ini".source;
  LOCK_COMMAND = "${pkgs.gtklock}/bin/gtklock";
  LOCK_TEST = ./wayland-lock.py;
  SLIDER_SOURCE = ../home/przvl/config/labwc/slider.py;
  SLIDER_TEST = ./wayland-sliders.py;
  PANEL_COMMAND = home.systemd.user.services.blix-wayland-panel.Service.ExecStart;
  PANEL_CONFIG = home.xdg.configFile."waybar/config".source;
  PANEL_STYLE = home.xdg.configFile."waybar/style.css".source;
  PANEL_TEST = ./wayland-panel-anchor.py;
  PANEL_PERFORMANCE_TEST = ./wayland-panel-performance.py;
  TASKBAR_TEST = ./wayland-taskbar.py;
  ICON_TEST = ./wayland-icons.py;
  ICON_DATA = home.xdg.dataFile."blix/wayland".source;
  ICON_SOURCE = ../home/przvl/config/labwc/icons/firefox.svg;
  ICON_FALLBACK = "${pkgs.adwaita-icon-theme}/share";
  ICON_MODERN = "${home.programs.firefox.finalPackage}/share";
  ICON_QT_TEST = iconLookup;
  FUZZEL_CONFIG = home.xdg.configFile."fuzzel/fuzzel.ini".source;
  FUZZEL_COMMAND = "${pkgs.fuzzel}/bin/fuzzel";
  QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}/platforms";
  DUNST_COMMAND = home.systemd.user.services.dunst.Service.ExecStart;
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
  mkdir "$out"
  cp lock-form.png locked.png "$out/"
''
