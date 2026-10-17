{ lib, pkgs, mkHost, fixture }:

let
  zen = (mkHost { modules = [ ../hosts/zen ]; }).config;
  t490 = (mkHost { modules = [ ../hosts/t490 ]; }).config;
  other = profile: (fixture {
    inherit profile;
    system = pkgs.stdenv.hostPlatform.system;
  }).config;
  controls = cfg:
    let home = cfg.home-manager.users.przvl;
    in home.blix.hardware.hasPowerProfiles
      && (builtins.fromJSON (builtins.unsafeDiscardStringContext home.xdg.configFile."blix/defaults.json".text)).capabilities.hasPowerProfiles
      && lib.hasInfix "export BLIX_HAS_POWER_PROFILES=1" home.home.file.".xinitrc".text;
  settings = cfg: cfg.services.tlp.settings;
in
assert lib.all (cfg: cfg.services.tlp.enable && cfg.services.tlp.pd.enable
  && !cfg.services.power-profiles-daemon.enable && controls cfg
  && (settings cfg).TLP_AUTO_SWITCH == 0
  && (settings cfg).CPU_ENERGY_PERF_POLICY_ON_AC == "performance"
  && (settings cfg).CPU_SCALING_GOVERNOR_ON_BAT == "powersave"
  && (settings cfg).CPU_BOOST_ON_BAT == 1
  && (settings cfg).CPU_BOOST_ON_SAV == 0
  && (settings cfg).CPU_ENERGY_PERF_POLICY_ON_SAV == "power"
  && (settings cfg).PLATFORM_PROFILE_ON_SAV == "low-power"
  && lib.all (suffix: (settings cfg).${"CPU_MAX_PERF_ON_" + suffix} == 100) [ "AC" "BAT" "SAV" ]
) [ zen t490 ];
assert (settings t490).CPU_ENERGY_PERF_POLICY_ON_BAT == "balance_performance";
assert (settings zen).CPU_ENERGY_PERF_POLICY_ON_BAT == "balance_power";
assert (settings t490).TLP_PROFILE_DEFAULT == "PRF" && (settings zen).TLP_PROFILE_DEFAULT == "BAL";
assert (settings t490).START_CHARGE_THRESH_BAT0 == 75 && (settings t490).STOP_CHARGE_THRESH_BAT0 == 80;
assert (settings zen).STOP_CHARGE_THRESH_BAT0 == 79;
assert lib.all (suffix: (settings t490).${"WIFI_PWR_ON_" + suffix} == "off") [ "AC" "BAT" ];
assert lib.all (cfg: !cfg.services.tlp.pd.enable && !cfg.home-manager.users.przvl.blix.hardware.hasPowerProfiles)
  (map other [ ../profiles/laptop.nix ../profiles/desktop.nix ../profiles/phone.nix ]);
pkgs.runCommand "power-profile-checks" { } ''
  touch "$out"
''
