{ pkgs, fixture }:

let
  host = fixture {
    profile = ../profiles/laptop.nix;
    system = pkgs.stdenv.hostPlatform.system;
  };
  home = host.config.home-manager.users.przvl;
  python = pkgs.python3.withPackages (ps: [ ps.dbus-python ps.python-xlib ]);
in
assert home.services.dunst.enable;
assert home.dconf.settings."org/blueman/general".notification-daemon;
assert builtins.elem "dunst.service" home.systemd.user.targets.blix-session.Unit.Wants;
assert home.systemd.user.services.dunst.Unit.PartOf == [ "blix-session.target" "blix-wayland-session.target" ];
pkgs.runCommand "notification-checks" {
  nativeBuildInputs = [ python pkgs.dbus pkgs.xvfb pkgs.dunst ];
  FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
} ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
    python3 ${./notifications.py} ${home.xdg.configFile."dunst/dunstrc".source}
  touch "$out"
''
