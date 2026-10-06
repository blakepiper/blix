# Host display connectors, scaling and wallpaper.
{ ... }:

{
  blix.display = {
    primaryOutput = "eDP-1";
    externalOutput = "HDMI-1";
    # USB-C dock HDMI adapters appear as dynamically numbered DP/MST outputs.
    additionalExternalOutputs = [ "DP-*" ];
    mirrorMode = "1920x1080";
    mirrorRate = "60";
    # Keep the native 2880x1800 panel sharp while presenting a 1.75x larger
    # logical desktop when no external monitor is connected. These rounded
    # logical dimensions preserve the panel's 16:10 aspect ratio.
    primaryScaleFrom = "1646x1029";
    wallpaper = "/home/przvl/Pictures/vibe.jpg";
  };
}
