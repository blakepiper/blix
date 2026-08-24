# Shared Blix system configuration.
#
# Hosts import this directory for the standard Blix operating environment,
# then add an optional machine-class module and their own hardware settings.
{ pkgs, ... }:

let
  blixSddmTheme = import ./sddm-theme.nix { inherit pkgs; };
in
{
  _module.args = { inherit blixSddmTheme; };

  imports = [
    ./boot.nix
    ./desktop-services.nix
    ./desktop-session.nix
    ./fonts.nix
    ./form-factor.nix
    ./home-manager.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./users.nix
  ];
}
