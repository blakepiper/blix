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
      description = "Whether to apply the additional touchpad click and tap defaults.";
    };
    hasLid = lib.mkEnableOption "lid-triggered suspend";
    hasBluetooth = lib.mkEnableOption "Bluetooth support for wireless peripherals";
  };

  config = {
    # Pass capabilities to Home Manager once, without hostname checks in user
    # configuration. Hardware exceptions belong in the host's system module.
    home-manager.users.przvl.blix = {
      hardware = {
        hasBattery = cfg.hasBattery;
        hasBacklight = cfg.hasBacklight;
        hasBluetooth = config.hardware.bluetooth.enable;
      };
    };
  };
}
