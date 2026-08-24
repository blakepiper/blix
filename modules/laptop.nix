# Configuration shared by every Blix laptop.
#
# Applied automatically to any host that sets `blix.formFactor = "laptop"`.
# Machine-specific power quirks still belong in hosts/<hostname>/default.nix.
{ config, lib, ... }:

{
  config = lib.mkIf (config.blix.formFactor == "laptop") {
    powerManagement.enable = true;
    services.power-profiles-daemon.enable = true;

    # Suspend on lid close, but keep running while docked to an external
    # display.
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
