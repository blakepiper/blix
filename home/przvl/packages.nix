{ pkgs, ... }:

# Reusable command-line tools, selected independently by each user composition.
{
  programs.bat = {
    enable = true;
    config.theme = "tokyonight_night";
    themes.tokyonight_night = {
      src = pkgs.vimPlugins.tokyonight-nvim.src;
      file = "extras/sublime/tokyonight_night.tmTheme";
    };
  };
  xdg.configFile."lazygit/config.yml".source =
    "${pkgs.vimPlugins.tokyonight-nvim.src}/extras/lazygit/tokyonight_night.yml";

  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    curl
    gcc
    jq
    eza
    lazygit
    less
    man
    unzip
    bash-completion
    codex
    cmatrix
    bubblewrap
    blesh
  ];
}
