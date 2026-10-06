{ config, lib, pkgs, ... }:

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
    };
  };

  # Ghostty 1.3.1 reads `cl` only from OSC 133;A. Initialize it before
  # ble.sh starts drawing; later prompt hooks use P without moving the cursor.
  programs.bash.initExtra = lib.mkOrder 102 ''
    if [[ ''${TERM_PROGRAM:-} == ghostty && -z ''${BLE_VERSION-} ]]; then
      builtin printf '\e]133;A;redraw=last;cl=line;aid=%s\a' "$BASHPID"
    fi
  '';

  home.sessionVariables.TERMINAL = lib.getExe config.programs.ghostty.package;
}
