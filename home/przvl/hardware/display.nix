{ lib, pkgs, blixDisplayEnvironment, ... }:

let
  displayHotplug = pkgs.writeShellApplication {
    name = "blix-display-hotplug";
    runtimeInputs = [ pkgs.coreutils pkgs.feh pkgs.gawk pkgs.systemd pkgs.xrandr pkgs.xset ];
    text = builtins.readFile ./display-hotplug.sh;
  };
in
{
  options.blix.display = {
    layout = lib.mkOption {
      type = lib.types.enum [ "mirror" "extend" ];
      default = "extend";
      description = "Mirror configured external outputs or extend across all connected monitors.";
    };
    primaryOutput = lib.mkOption {
      type = lib.types.str;
      description = "Primary XRandR connector: an internal panel or a desktop monitor.";
    };
    primaryRotation = lib.mkOption {
      type = lib.types.enum [ "normal" "left" "right" "inverted" ];
      default = "normal";
      description = "XRandR rotation of the primary panel, applied on startup and hotplug.";
    };
    dpi = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Optional X11 and Xft DPI for fonts and application UI sizing.";
    };
    blankAfterSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Idle time before DPMS powers off the display; zero disables automatic blanking.";
    };
    externalOutput = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "External XRandR connector to mirror; null when none is configured.";
    };
    additionalExternalOutputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional XRandR connector glob patterns to mirror, including dynamic dock outputs.";
    };
    mirrorMode = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
      description = "Mode used for the mirrored external output.";
    };
    mirrorRate = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional fixed mirrored refresh rate; null selects each output's highest available rate.";
    };
    primaryScaleFrom = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Logical XRandR mode used for the primary output outside mirror mode.";
    };
    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to the host wallpaper applied when the X11 session starts.";
    };
  };

  config = {
    _module.args = { inherit displayHotplug; };
    home.packages = [ displayHotplug ];

    systemd.user.targets.blix-session.Unit.Wants = [ "blix-display-hotplug.service" ];
    systemd.user.services.blix-display-hotplug = {
      # Restart during a Home Manager switch in an already-running session.
      Install.WantedBy = [ "blix-session.target" ];
      Unit = {
        Description = "Configure monitor layout on hotplug";
        PartOf = [ "blix-session.target" ];
        After = [ "blix-lock.service" ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${displayHotplug}/bin/blix-display-hotplug";
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") blixDisplayEnvironment;
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
