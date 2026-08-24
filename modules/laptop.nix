# Configuration shared by every Blix laptop.
#
# Applied automatically to any host that sets `blix.formFactor = "laptop"`.
# Machine-specific power quirks still belong in hosts/<hostname>/default.nix.
{ config, lib, ... }:

{
  config = lib.mkIf (config.blix.formFactor == "laptop") {
    services.power-profiles-daemon.enable = true;

    # Keep Xfce's libinput behavior aligned with the shared Hyprland input
    # settings without naming a particular machine's touchpad.
    services.libinput.touchpad = {
      clickMethod = "clickfinger";
      naturalScrolling = true;
      tapping = true;
      tappingButtonMap = "lrm";
    };

    # Suspend on lid close, but keep running while docked to an external
    # display.
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
