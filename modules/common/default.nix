# Shared Blix-style system configuration.
#
# Hosts import this directory for the common X11/OXWM environment and their
# generated hardware settings. There is deliberately no display manager:
# `startx` from a local TTY is the session entry point.
{ ... }:

{
  # Home Manager uses dconf for GTK cursor settings and other desktop
  # preferences. Provide the session service it talks to during activation.
  programs.dconf.enable = true;

  imports = [
    ./boot.nix
    ./desktop-services.nix
    ./desktop-session.nix
    ./hyprland.nix
    ./fonts.nix
    ./home-manager.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./users.nix
  ];
}
