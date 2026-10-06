# User capabilities supplied by the NixOS machine profile.
{ lib, ... }:

{
  imports = [ ./bluetooth.nix ./display.nix ];

  options.blix.hardware = {
    hasBattery = lib.mkEnableOption "battery reporting, supplied by the machine profile";
    hasBacklight = lib.mkEnableOption "internal-panel brightness controls, supplied by the machine profile";
    hasBluetooth = lib.mkEnableOption "Bluetooth controls, supplied by the system hardware module";
  };
}
