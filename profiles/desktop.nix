# Stationary workstations select the shared desktop and user environment.
{ lib, pkgs, ... }:

{
  imports = [ ../modules/common ../modules/desktop ../modules/desktop/labwc.nix ../modules/hardware/suspend.nix ../modules/boot/uefi.nix ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  home-manager.users.przvl.imports = [ ../home/przvl ];
  blix.machine.type = lib.mkDefault "desktop";
}
