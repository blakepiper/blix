# Host display connectors, scaling and wallpaper.
{ ... }:

{
  # DRM HDMI names differ from XRandR; dock DP/MST names are dynamic.
  blix.wayland.externalOutputs = [ "HDMI-A-*" "DP-*" ];
  blix.wayland.outputs."eDP-1".scale = 1.25;
  blix.display = {
    primaryOutput = "eDP-1";
    externalOutput = "HDMI-2";
    # The Dell dock exposes its HDMI monitor through dynamic DP/MST outputs.
    additionalExternalOutputs = [ "DP-*" ];
    mirrorMode = "1920x1080";
    # 125% application scaling relative to the standard 96 DPI baseline.
    dpi = 120;
    wallpaper = "/home/przvl/Pictures/cityviewred.png";
  };
}
