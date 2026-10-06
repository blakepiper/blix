# Stationary machines inherit the common OXWM environment and desktop defaults.
{ lib, ... }:

{
  imports = [ ../modules/common ../modules/boot/uefi.nix ];
  blix.machine.type = lib.mkDefault "desktop";
}
