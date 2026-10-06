{ pkgs, ... }:

{
  # Install the unconfigured package; tmux uses its upstream defaults.
  home.packages = with pkgs; [ tmux ];
}
