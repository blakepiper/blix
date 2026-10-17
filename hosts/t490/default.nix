# ThinkPad T490 — host-specific configuration.
#
# Shared configuration is composed here with the generated hardware module and
# the few settings that genuinely depend on this machine.
{ ... }:

{
  imports = [
    ../../profiles/laptop.nix
    ./hardware-configuration.nix
    ../../modules/hardware/graphics/intel.nix
    ../../modules/hardware/power-profiles/intel.nix
  ];

  # Home Manager settings that depend on this machine, merged with the
  # workstation user configuration selected by the laptop profile.
  home-manager.users.przvl = import ./home.nix;

  networking.hostName = "t490";

  # This laptop's Wi-Fi adapter drops connections intermittently with
  # aggressive power saving enabled.
  networking.networkmanager.wifi.powersave = false;

  # The native ThinkPad battery controls support a 75–80% charging range.
  services.tlp = {
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
      # Preserve the initial performance preference; favor responsiveness in
      # Balanced on this Whiskey Lake CPU.
      TLP_PROFILE_DEFAULT = "PRF";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
      # Preserve the Wi-Fi workaround. TLP uses _BAT for Wi-Fi in both
      # balanced and power-saver profiles.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
    };
  };

  # The NixOS release this machine was installed with. Per host; never copied
  # to a new machine.
  system.stateVersion = "26.05";
}
