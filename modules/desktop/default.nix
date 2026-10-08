# Reusable Blix desktop environment. Each profile opts in explicitly.
{ ... }:

{
  imports = [
    ../hardware/x11.nix
    ./fonts.nix
    ./packages.nix
    ./services.nix
    ./session.nix
  ];

  # Home Manager's GTK preferences need dconf during activation.
  programs.dconf.enable = true;
}
