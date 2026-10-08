# Stationary workstations select the shared desktop and user environment.
{ lib, ... }:

{
  imports = [ ../modules/common ../modules/desktop ../modules/boot/uefi.nix ];
  home-manager.users.przvl.imports = [ ../home/przvl ];
  blix.machine.type = lib.mkDefault "desktop";
}
