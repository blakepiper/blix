# Portable workstations share one system and Home Manager environment.
{ lib, ... }:

{
  imports = [ ../modules/common ../modules/desktop ../modules/boot/uefi.nix ];

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
