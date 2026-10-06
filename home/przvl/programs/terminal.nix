{ config, lib, pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
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
      window-decoration = "none";
      window-padding-x = 2;
      window-padding-y = 2;
    };
  };

  home.sessionVariables.TERMINAL = lib.getExe config.programs.ghostty.package;
}
