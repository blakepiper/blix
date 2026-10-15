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
      bashProfile = home.home.file.".bash_profile".source;
      profile = home.home.file.".profile".source;
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

  # Execute the generated login files, rather than an unused home.file.text.
  # Only the two hardware/session commands are replaced with harmless stubs.
  bash -n "${phone.bashProfile}"
  bash -n "${phone.profile}"
  mkdir -p "$TMPDIR/phone-home" "$TMPDIR/login-bin"
  : > "$TMPDIR/phone-home/.bashrc"
  cat > "$TMPDIR/login-bin/tty" <<'STUB'
  #!${pkgs.bash}/bin/bash
  printf '%s\n' "$BLIX_TEST_TTY"
  STUB
  cat > "$TMPDIR/login-bin/startx" <<'STUB'
  #!${pkgs.bash}/bin/bash
  printf '%s\n' "$*" >> "$BLIX_TEST_STARTX_LOG"
  STUB
  chmod +x "$TMPDIR/login-bin/tty" "$TMPDIR/login-bin/startx"
  substitute "${phone.profile}" "$TMPDIR/phone-home/.profile" \
    --replace-fail '${pkgs.coreutils}/bin/tty' "$TMPDIR/login-bin/tty" \
    --replace-fail '${pkgs.xinit}/bin/startx' "$TMPDIR/login-bin/startx"
  export BLIX_TEST_STARTX_LOG="$TMPDIR/startx.log"
  unset DISPLAY
  HOME="$TMPDIR/phone-home" BLIX_TEST_TTY=/dev/tty1 bash "${phone.bashProfile}"
  grep -qx -- '-- :0 vt1 -keeptty' "$BLIX_TEST_STARTX_LOG"
  : > "$BLIX_TEST_STARTX_LOG"
  for login_tty in /dev/tty2 /dev/pts/0; do
    HOME="$TMPDIR/phone-home" BLIX_TEST_TTY="$login_tty" bash "${phone.bashProfile}"
  done
  HOME="$TMPDIR/phone-home" BLIX_TEST_TTY=/dev/tty1 DISPLAY=:1 bash "${phone.bashProfile}"
  test ! -s "$BLIX_TEST_STARTX_LOG"
  if grep -q startx "${laptop.bashProfile}" "${laptop.profile}"; then
    echo 'Workstation login must remain manual' >&2
    exit 1
  fi
  touch "$out"
''
