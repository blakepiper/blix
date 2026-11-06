{ pkgs, ... }:

{
  programs.btop.enable = true;
  programs.btop.settings.color_theme = "${pkgs.vimPlugins.tokyonight-nvim.src}/extras/btop/tokyonight_night.theme";
}
