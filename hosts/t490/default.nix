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
      TLP_PROFILE_AC = "PRF";
      TLP_PROFILE_BAT = "PRF";
      TLP_PROFILE_DEFAULT = "PRF";
      # Prefer responsiveness in every TLP mode, including low-battery mode.
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "performance";
      CPU_SCALING_GOVERNOR_ON_SAV = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "performance";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "performance";
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "performance";
      PLATFORM_PROFILE_ON_SAV = "performance";
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MAX_PERF_ON_BAT = 100;
      CPU_MAX_PERF_ON_SAV = 100;
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;
      CPU_BOOST_ON_SAV = 1;
      # Preserve the Wi-Fi workaround when TLP applies its power policy.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
    };
  };

  # The NixOS release this machine was installed with. Per host; never copied
  # to a new machine.
  system.stateVersion = "26.05";
}
