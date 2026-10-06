# Shared Blix-style system configuration.
#
# Machine profiles import this common X11/OXWM environment. Hosts
# compose a profile with their generated hardware settings. No display manager:
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
    ./fonts.nix
    ./home-manager.nix
    ./locale.nix
    ./machine.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./users.nix
  ];
}
