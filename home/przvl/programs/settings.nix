{ config, osConfig, lib, pkgs, blixLock, ... }:

let
  blixSettings = pkgs.callPackage ../../../packaging/blix-settings { };
  speed = value: if value == null then 0 else builtins.fromJSON value;
in
{
  _module.args = { inherit blixSettings; };
  home.packages = [ blixSettings ];

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
    shortcutsFile = "${config.home.homeDirectory}/.config/oxwm/config.lua";
  };

  systemd.user.targets.blix-session.Unit.Wants = [ "blix-settings-input.service" ];
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
