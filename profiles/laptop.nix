# Portable machines inherit the common OXWM environment and laptop defaults.
{ lib, ... }:

{
  imports = [ ../modules/common ../modules/boot/uefi.nix ];

  blix.machine = {
    type = lib.mkDefault "laptop";
    hasBattery = lib.mkDefault true;
    hasBacklight = lib.mkDefault true;
    hasTouchpad = lib.mkDefault true;
    hasLid = lib.mkDefault true;
  };

  home-manager.users.przvl.blix.display.layout = lib.mkDefault "mirror";
}
