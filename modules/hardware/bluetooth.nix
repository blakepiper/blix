{ config, lib, ... }:

{
  hardware.bluetooth = {
    enable = lib.mkDefault config.blix.machine.hasBluetooth;
    powerOnBoot = lib.mkDefault true;
  };
  services.blueman.enable = lib.mkDefault config.hardware.bluetooth.enable;
}
