{ config, lib, pkgs, ... }:

let
  # OXWM executes TERMINAL as one executable, so keep IPC arguments here.
  launcher = pkgs.writeShellScriptBin "blix-terminal" ''
    exec ${lib.getExe config.programs.ghostty.package} +new-window "$@"
  '';
in
{
  programs.ghostty = {
    enable = true;
    package = pkgs.callPackage ../../../packaging/ghostty {
      browser = config.programs.firefox.finalPackage;
    };
    enableBashIntegration = true;
    settings = {
      command = "${pkgs.bashInteractive}/bin/bash";
      shell-integration = "bash";
      shell-integration-features = "no-cursor";
      font-family = "JetBrainsMono Nerd Font";
      font-size = 11;
      background = "1a1b26";
      foreground = "bbbbbb";
      cursor-color = "bbbbbb";
      cursor-style = "block";
      cursor-click-to-move = true;
      link-url = true;
      mouse-shift-capture = "never";
      window-decoration = "none";
      window-padding-x = 2;
      window-padding-y = 2;
      # Retain the initialized app between windows; the X session owns its life.
      quit-after-last-window-closed = false;
    };
  };

  # Ghostty 1.3.1 reads `cl` only from OSC 133;A. Initialize it before
  # ble.sh starts drawing; later prompt hooks use P without moving the cursor.
  programs.bash.initExtra = lib.mkOrder 102 ''
    if [[ ''${TERM_PROGRAM:-} == ghostty && -z ''${BLE_VERSION-} ]]; then
      builtin printf '\e]133;A;redraw=last;cl=line;aid=%s\a' "$BASHPID"
    fi
  '';

  home.sessionVariables.TERMINAL = lib.getExe launcher;

  # Home Manager already installs Ghostty's D-Bus activation and user unit.
  # Start it after the manual X session imports DISPLAY, without opening a window.
  systemd.user.targets.blix-session.Unit.Wants = [ "app-com.mitchellh.ghostty.service" ];
  xdg.configFile."systemd/user/app-com.mitchellh.ghostty.service.d/blix-session.conf".text = ''
    [Unit]
    PartOf=blix-session.target
    ConditionEnvironment=DISPLAY
  '';
}
