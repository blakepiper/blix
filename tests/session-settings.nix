# Exercise session settings with harmless X11 substitutes, and activation without
# a user bus. No live desktop settings or compositor services are changed.
{ pkgs, fixture }:

let
  settings = profile: modules:
    let host = fixture {
      inherit profile modules;
      system = pkgs.stdenv.hostPlatform.system;
    };
    home = host.config.home-manager.users.przvl;
    in {
      session = builtins.head home.systemd.user.services.blix-session-settings.Service.ExecStart;
      picomOnChange = pkgs.writeShellScript "picom-on-change"
        home.home.file.".config/picom/picom.conf".onChange;
    };
  laptop = settings ../profiles/laptop.nix [ ];
  phone = settings ../profiles/phone.nix [
    { home-manager.users.przvl.blix.display.dpi = 192; }
  ];
in
pkgs.runCommand "session-settings-checks" {
  nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ];
} ''
  export BLIX_TEST_COMMANDS="$TMPDIR/xset.log"
  xset() { printf '%s\n' "$*" >> "$BLIX_TEST_COMMANDS"; }
  xrdb() {
    test "$1" = -merge
    grep -qx 'Xft.dpi: 192' "$2"
    printf 'xrdb merged\n' >> "$BLIX_TEST_COMMANDS"
  }
  export -f xset xrdb

  "${laptop.session}"
  grep -qx 'r rate 200 50' "$BLIX_TEST_COMMANDS"
  grep -qx 'dpms 0 0 0' "$BLIX_TEST_COMMANDS"
  if grep -q 'xrdb merged' "$BLIX_TEST_COMMANDS"; then exit 1; fi

  : > "$BLIX_TEST_COMMANDS"
  "${phone.session}"
  grep -qx 'dpms 0 0 300' "$BLIX_TEST_COMMANDS"
  grep -qx 'xrdb merged' "$BLIX_TEST_COMMANDS"

  # A first install has no user bus. The reload hook must still succeed.
  export XDG_RUNTIME_DIR="$TMPDIR/no-user-session"
  mkdir -m 700 "$XDG_RUNTIME_DIR"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/absent-bus"
  bash -e "${phone.picomOnChange}"
  touch "$out"
''
