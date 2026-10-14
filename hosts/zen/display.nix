# Host display connectors, scaling and wallpaper.
{ ... }:

{
  blix.display = {
    primaryOutput = "eDP-1";
    externalOutput = "HDMI-1";
    # USB-C dock HDMI adapters appear as dynamically numbered DP/MST outputs.
    additionalExternalOutputs = [ "DP-*" ];
    mirrorMode = "1920x1080";
    # Match the T490's 125% application scaling without extra monitor zoom.
    dpi = 120;
    wallpaper = "/home/przvl/Pictures/tukeesunset.png";
  };
}
