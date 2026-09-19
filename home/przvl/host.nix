# Facts about the machine this user configuration is running on.
#
# Hosts supply the display values below to describe Blix's XRandR mirror setup;
# each host can override them independently.
{ lib, ... }:

{
  options.blix = {
    display = {
      internalOutput = lib.mkOption {
        type = lib.types.str;
        default = "eDP-1";
        description = "Internal XRandR connector used as the mirror source.";
      };
      externalOutput = lib.mkOption {
        type = lib.types.str;
        default = "HDMI-2";
        description = "External XRandR connector mirrored to the internal panel.";
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
      internalScaleFrom = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Logical XRandR mode used for the internal panel when no external output is connected.";
      };
      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to the host wallpaper applied when the X11 session starts.";
      };
    };
  };
}
