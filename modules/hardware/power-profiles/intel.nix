{ lib, ... }:

{
  # Intel HWP laptops: TLP owns device policy and exposes its three real profiles
  # through tlp-pd. _AC/_BAT/_SAV mean performance/balanced/power-saver even when
  # selected manually on a different power source.
  services.tlp = {
    enable = true;
    pd.enable = true;
    settings = lib.mapAttrs (_: lib.mkDefault) {
      # A manual choice stays in effect through charger changes and suspend.
      # Blix Settings restores the user's saved choice at the next login.
      TLP_AUTO_SWITCH = 0;
      TLP_PROFILE_DEFAULT = "BAL";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_SAV = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PLATFORM_PROFILE_ON_SAV = "low-power";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MIN_PERF_ON_SAV = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MAX_PERF_ON_BAT = 100;
      CPU_MAX_PERF_ON_SAV = 100;
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;
      CPU_BOOST_ON_SAV = 0;
      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 1;
      CPU_HWP_DYN_BOOST_ON_SAV = 0;
    };
  };
}
