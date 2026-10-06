# Facts about the machine this user configuration is running on.
#
# Profiles supply hardware capabilities; hosts supply their display connectors.
{ lib, ... }:

{
  options.blix = {
    hardware = {
      hasBattery = lib.mkEnableOption "battery reporting, supplied by the machine profile";
      hasBacklight = lib.mkEnableOption "internal-panel brightness controls, supplied by the machine profile";
    };
    display = {
      layout = lib.mkOption {
        type = lib.types.enum [ "mirror" "extend" ];
        default = "extend";
        description = "Mirror configured external outputs or extend across all connected monitors.";
      };
      primaryOutput = lib.mkOption {
        type = lib.types.str;
        description = "Primary XRandR connector: an internal panel or a desktop monitor.";
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
        type = lib.types.str;
        default = "60";
        description = "Refresh rate used for the mirrored external output.";
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
  };
}
