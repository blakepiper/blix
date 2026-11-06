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
      foreground = "c0caf5";
      # Match Neovim's terminal palette so ANSI artwork stays vivid.
      palette = [
        "0=#15161e" "1=#f7768e" "2=#9ece6a" "3=#e0af68"
        "4=#7aa2f7" "5=#bb9af7" "6=#7dcfff" "7=#a9b1d6"
        "8=#414868" "9=#ff899d" "10=#9fe044" "11=#faba4a"
        "12=#8db0ff" "13=#c7a9ff" "14=#a4daff" "15=#c0caf5"
      ];
      cursor-color = "c0caf5";
      selection-background = "283457";
      selection-foreground = "c0caf5";
      cursor-style = "block";
      cursor-click-to-move = true;
      link-url = true;
      copy-on-select = "clipboard";
      confirm-close-surface = false;
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
