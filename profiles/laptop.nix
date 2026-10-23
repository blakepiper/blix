# Portable workstations share one system and Home Manager environment.
{ lib, pkgs, ... }:

{
  imports = [ ../modules/common ../modules/desktop ../modules/boot/uefi.nix ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  home-manager.users.przvl.imports = [ ../home/przvl ];

  blix.machine = {
    type = lib.mkDefault "laptop";
    hasBattery = lib.mkDefault true;
    hasBacklight = lib.mkDefault true;
    hasTouchpad = lib.mkDefault true;
    hasLid = lib.mkDefault true;
    hasBluetooth = lib.mkDefault true;
  };

  home-manager.users.przvl.blix.display.layout = lib.mkDefault "mirror";
}
