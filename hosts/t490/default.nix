# ThinkPad T490 — host-specific configuration.
#
# Shared and laptop-class configuration is composed here with the generated
# hardware module and the few settings that genuinely depend on this machine.
{ ... }:

{
  imports = [
    ../../modules/common
    ../../modules/laptop
    ./hardware-configuration.nix
    ./power.nix
  ];

  # Home Manager settings that depend on this machine, merged with the
  # shared home/przvl configuration applied in modules/common/.
  home-manager.users.przvl = import ./home.nix;

  blix.formFactor = "laptop";

  networking.hostName = "t490";

  # This laptop's Wi-Fi adapter drops connections intermittently with
  # aggressive power saving enabled.
  networking.networkmanager.wifi.powersave = false;

  # The NixOS release this machine was installed with. Per host; never copied
  # to a new machine.
  system.stateVersion = "26.05";
}
