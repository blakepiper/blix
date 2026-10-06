# Host display connectors, scaling and wallpaper.
{ ... }:

{
  blix.display = {
    primaryOutput = "eDP-1";
    externalOutput = "HDMI-2";
    # The Dell dock exposes its HDMI monitor through dynamic DP/MST outputs.
    additionalExternalOutputs = [ "DP-*" ];
    mirrorMode = "1920x1080";
    wallpaper = "/home/przvl/Pictures/forest.jpg";
  };
}
