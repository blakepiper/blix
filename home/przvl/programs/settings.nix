{ config, osConfig, lib, pkgs, blixLock, ... }:

let
  blixSettings = pkgs.callPackage ../../../packaging/blix-settings {
    hyprland = if osConfig.programs.hyprland.enable then osConfig.programs.hyprland.package else null;
  };
  speed = value: if value == null then 0 else builtins.fromJSON value;
in
{
  _module.args = { inherit blixSettings; };
  home.packages = [ blixSettings ];
  xdg.configFile."hypr/hyprsunset.conf" = lib.mkIf osConfig.programs.hyprland.enable {
    text = ''
      profile {
        time = 00:00
        identity = true
      }
    '';
  };

  # These immutable defaults are separate from the app's writable settings.json.
  # No machine-specific connector names or hardware assumptions live in the app.
  xdg.configFile."blix/defaults.json".text = builtins.toJSON {
    capabilities = config.blix.hardware;
    display = config.blix.display;
    keyboard = {
      delay = osConfig.services.xserver.autoRepeatDelay;
      rate = builtins.div 1000 osConfig.services.xserver.autoRepeatInterval;
    };
    input = {
      mouse = {
        speed = speed osConfig.services.libinput.mouse.accelSpeed;
        # The focused mouse module applies this only to ordinary mice.
        natural = true;
      };
      touchpad = {
        speed = speed osConfig.services.libinput.touchpad.accelSpeed;
        natural = osConfig.services.libinput.touchpad.naturalScrolling;
        tapping = osConfig.services.libinput.touchpad.tapping;
      };
    };
    lockCommand = "${blixLock}/bin/blix-lock";
    suspendCommand = config.blix.power.suspendCommand or null;
    shortcutsFile = "${config.home.homeDirectory}/.config/oxwm/config.lua";
  };

  systemd.user.targets.blix-session.Unit.Wants = [ "blix-settings-input.service" "blix-nightlight.service" ];
  systemd.user.services.blix-nightlight = {
    Install.WantedBy = [ "blix-session.target" ];
    Unit = {
      Description = "Blix night light color adjustment";
      PartOf = [ "blix-session.target" ];
      After = [ "blix-session-settings.service" ];
      ConditionEnvironment = "DISPLAY";
    };
    Service = {
      Type = "exec";
      ExecStart = "${blixSettings}/bin/blix-settings-apply nightlight";
      ExecStopPost = "${pkgs.gammastep}/bin/gammastep -m randr -x";
    };
  };
  systemd.user.services.blix-hyprsunset = lib.mkIf osConfig.programs.hyprland.enable {
    Unit = {
      Description = "Blix night light color adjustment for Hyprland";
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset";
      ExecStartPost = "${blixSettings}/bin/blix-settings-apply apply-hyprland-nightlight";
      Restart = "on-failure";
    };
  };
  systemd.user.services.blix-settings-input = {
    Install.WantedBy = [ "blix-session.target" ];
    Unit = {
      Description = "Apply saved Blix pointing-device preferences on connection";
      PartOf = [ "blix-session.target" ];
      After = [ "blix-session-settings.service" ];
      ConditionEnvironment = "DISPLAY";
    };
    Service = {
      Type = "exec";
      ExecStart = "${blixSettings}/bin/blix-settings-apply watch-input";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
