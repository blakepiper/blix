{ config, lib, ... }:

{
  hardware.bluetooth = {
    enable = lib.mkDefault config.blix.machine.hasBluetooth;
    powerOnBoot = lib.mkDefault true;
  };
}
