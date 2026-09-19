{ pkgs, ... }:

{
  # The complete editor configuration is installed by x11.nix. Keep Neovim
  # as a plain package here so Home Manager does not generate a competing
  # init.lua beside the managed configuration directory.
  home.packages = [ pkgs.neovim ];
}
