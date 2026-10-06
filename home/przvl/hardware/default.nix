# User capabilities supplied by the NixOS machine profile.
{ lib, ... }:

{
  imports = [ ./display.nix ];

  options.blix.hardware = {
    hasBattery = lib.mkEnableOption "battery reporting, supplied by the machine profile";
    hasBacklight = lib.mkEnableOption "internal-panel brightness controls, supplied by the machine profile";
  };
}
