{ config, lib, ... }:

let
  cfg = config.blix.machine;
  laptop = cfg.type == "laptop";
in
{
  options.blix.machine = {
    type = lib.mkOption {
      type = lib.types.enum [ "laptop" "desktop" ];
      description = "Machine class supplied by the host's inherited profile.";
    };
    hasBattery = lib.mkOption {
      type = lib.types.bool;
      default = laptop;
      defaultText = lib.literalExpression ''config.blix.machine.type == "laptop"'';
      description = "Whether to include battery reporting and its status-bar helper.";
    };
    hasBacklight = lib.mkOption {
      type = lib.types.bool;
      default = laptop;
      defaultText = lib.literalExpression ''config.blix.machine.type == "laptop"'';
      description = "Whether to include internal-panel brightness controls.";
    };
    hasTouchpad = lib.mkOption {
      type = lib.types.bool;
      default = laptop;
      defaultText = lib.literalExpression ''config.blix.machine.type == "laptop"'';
      description = "Whether to apply the shared touchpad settings.";
    };
  };

  config = {
    # Make lid policy explicit. A docked laptop stays awake for its external
    # monitors; a desktop ignores lid events. Hosts can override these defaults.
    services.logind.settings.Login = {
      HandleLidSwitch = lib.mkDefault (if laptop then "suspend" else "ignore");
      HandleLidSwitchExternalPower = lib.mkDefault (if laptop then "suspend" else "ignore");
      HandleLidSwitchDocked = lib.mkDefault "ignore";
    };

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
      display.layout = lib.mkDefault (if laptop then "mirror" else "extend");
    };
  };
}
