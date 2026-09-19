{ pkgs, ... }:

{
  # The complete tmux configuration is installed by x11.nix. Keep tmux as a
  # plain package so Home Manager does not prepend its own default settings.
  home.packages = [ pkgs.tmux ];
}
