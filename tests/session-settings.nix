# Exercise the generated script, including its Xresources input, with harmless
# substitutes for the X11 commands. No live desktop settings are changed.
{ pkgs, fixture }:

let
  settings = profile: modules:
    let host = fixture {
      inherit profile modules;
      system = pkgs.stdenv.hostPlatform.system;
    }; in
    builtins.head host.config.home-manager.users.przvl.systemd.user.services.blix-session-settings.Service.ExecStart;
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

  "${laptop}"
  grep -qx 'r rate 200 50' "$BLIX_TEST_COMMANDS"
  grep -qx 'dpms 0 0 0' "$BLIX_TEST_COMMANDS"
  if grep -q 'xrdb merged' "$BLIX_TEST_COMMANDS"; then exit 1; fi

  : > "$BLIX_TEST_COMMANDS"
  "${phone}"
  grep -qx 'dpms 0 0 300' "$BLIX_TEST_COMMANDS"
  grep -qx 'xrdb merged' "$BLIX_TEST_COMMANDS"
  touch "$out"
''
