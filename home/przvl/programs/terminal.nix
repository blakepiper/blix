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
      # Match Neovim's terminal palette so ANSI artwork stays vivid.
      palette = [
        "0=#000000" "1=#cd0000" "2=#00cd00" "3=#cdcd00"
        "4=#82b4ff" "5=#cd00cd" "6=#00cdcd" "7=#e5e5e5"
        "8=#7f7f7f" "9=#ff0000" "10=#00ff00" "11=#ffff00"
        "12=#a6c8ff" "13=#ff00ff" "14=#00ffff" "15=#ffffff"
      ];
      cursor-color = "bbbbbb";
      cursor-style = "block";
      cursor-click-to-move = true;
      link-url = true;
      copy-on-select = "clipboard";
      # Keep Shift+drag selection available in mouse-capturing apps like Codex.
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

    [Service]
    # Ghostty 1.3.1 can notify READY before installing its SIGUSR2 handler.
    # systemd 262 rejects notify-reload startup in that race (upstream #14399).
    # Keep readiness notification and explicit config reload until it ships.
    Type=notify
    ExecReload=${pkgs.coreutils}/bin/kill -USR2 $MAINPID
  '';
}
