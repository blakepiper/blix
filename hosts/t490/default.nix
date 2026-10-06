# ThinkPad T490 — host-specific configuration.
#
# Shared configuration is composed here with the generated hardware module and
# the few settings that genuinely depend on this machine.
{ ... }:

{
  imports = [
    ../../profiles/laptop.nix
    ./hardware-configuration.nix
  ];

  # Home Manager settings that depend on this machine, merged with the
  # shared home/przvl configuration applied in modules/common/.
  home-manager.users.przvl = import ./home.nix;

  networking.hostName = "t490";

  # This laptop's Wi-Fi adapter drops connections intermittently with
  # aggressive power saving enabled.
  networking.networkmanager.wifi.powersave = false;

  # The native ThinkPad battery controls support a 75–80% charging range.
  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
      # Preserve the Wi-Fi workaround when TLP applies its power policy.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
    };
  };

  # The NixOS release this machine was installed with. Per host; never copied
  # to a new machine.
  system.stateVersion = "26.05";
}
