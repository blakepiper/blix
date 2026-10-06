{ config, lib, ... }:

let
  cfg = config.blix.machine;
in
{
  options.blix.machine = {
    type = lib.mkOption {
      type = lib.types.enum [ "laptop" "desktop" "phone" ];
      description = "Machine class supplied by the host's inherited profile.";
    };
    hasBattery = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to include battery reporting and its status-bar helper.";
    };
    hasBacklight = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to include internal-panel brightness controls.";
    };
    hasTouchpad = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to apply the shared touchpad settings.";
    };
    hasLid = lib.mkEnableOption "lid-triggered suspend";
    hasBluetooth = lib.mkEnableOption "Bluetooth support for wireless peripherals";
  };

  config = {
    # Power behavior follows capabilities, independently of the profile name.
    services.logind.settings.Login = {
      HandleLidSwitch = lib.mkDefault (if cfg.hasLid then "suspend" else "ignore");
      HandleLidSwitchExternalPower = lib.mkDefault (if cfg.hasLid then "suspend" else "ignore");
      HandleLidSwitchDocked = lib.mkDefault "ignore";
    };

    hardware.bluetooth.enable = lib.mkDefault cfg.hasBluetooth;

    services.libinput.touchpad = lib.mkIf cfg.hasTouchpad {
      clickMethod = lib.mkDefault "clickfinger";
      naturalScrolling = lib.mkDefault true;
      tapping = lib.mkDefault true;
      tappingButtonMap = lib.mkDefault "lrm";
      disableWhileTyping = lib.mkDefault true;
    };

    # Pass capabilities to Home Manager once, without hostname checks in user
    # configuration. Hardware exceptions belong in the host's system module.
    home-manager.users.przvl.blix = {
      hardware = {
        hasBattery = cfg.hasBattery;
        hasBacklight = cfg.hasBacklight;
      };
    };
  };
}
