# Shared Blix-style system configuration.
#
# Hosts import this directory for the common X11/OXWM environment and their
# generated hardware settings. There is deliberately no display manager:
# `startx` from a local TTY is the session entry point.
{ ... }:

{
  imports = [
    ./boot.nix
    ./desktop-services.nix
    ./desktop-session.nix
    ./fonts.nix
    ./home-manager.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./users.nix
  ];
}
