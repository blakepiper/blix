# Start the generated configuration on a synthetic output; never touch a real seat.
{ lib, pkgs, fixture }:
let
  laptop = fixture { profile = ../profiles/laptop.nix; system = pkgs.stdenv.hostPlatform.system; };
  phone = fixture { profile = ../profiles/phone.nix; system = pkgs.stdenv.hostPlatform.system; };
  home = laptop.config.home-manager.users.przvl;
  rc = pkgs.writeText "blix-labwc-rc.xml" home.xdg.configFile."labwc/rc.xml".text;
  theme = pkgs.writeText "blix-labwc-themerc" home.xdg.configFile."labwc/themerc".text;
  wants = home.systemd.user.targets.blix-wayland-session.Unit.Wants;
in
assert laptop.config.programs.labwc.enable;
assert laptop.config.services.xserver.windowManager.oxwm.enable;
assert !phone.config.programs.labwc.enable;
assert !(phone.config.home-manager.users.przvl.systemd.user.targets ? blix-wayland-session);
assert !lib.any (unit: builtins.elem unit wants) [ "blix-session.target" "blix-picom.service" "blix-lock.service" "blix-display-hotplug.service" ];
pkgs.runCommand "labwc-session-checks" {
  nativeBuildInputs = [ pkgs.labwc pkgs.python3 pkgs.wlr-randr pkgs.grim ];
} ''
  export HOME="$TMPDIR/home" XDG_RUNTIME_DIR="$TMPDIR/runtime"
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR" config
  chmod 700 "$XDG_RUNTIME_DIR"
  cp ${rc} config/rc.xml
  cp ${theme} config/themerc
  # Exclude session autostart: this check must not interact with a user manager.
  touch config/autostart config/shutdown config/environment
  export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_HEADLESS_OUTPUTS=1
  export XKB_CONFIG_ROOT=${pkgs.xkeyboard_config}/share/X11/xkb
  unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
  python3 ${./labwc.py}
  touch "$out"
''
