{ config, lib, ... }:

{
  # Lid policy follows the capability, independently of the profile name.
  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkDefault (if config.blix.machine.hasLid then "suspend" else "ignore");
    HandleLidSwitchExternalPower = lib.mkDefault (if config.blix.machine.hasLid then "suspend" else "ignore");
    HandleLidSwitchDocked = lib.mkDefault "ignore";
  };
}
