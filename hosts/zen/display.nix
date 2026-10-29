# Host display connectors, scaling and wallpaper.
{ ... }:

{
  blix.display = {
    primaryOutput = "eDP-1";
    externalOutput = "HDMI-1";
    # USB-C dock HDMI adapters appear as dynamically numbered DP/MST outputs.
    additionalExternalOutputs = [ "DP-*" ];
    mirrorMode = "1920x1080";
    # Present a 175% logical desktop on the native 2880x1800 panel when undocked.
    # DPI-only font scaling does not preserve this desktop zoom.
    primaryScaleFrom = "1646x1029";
    # Reset the previous 120 DPI override during live switches as well as login.
    dpi = 96;
    wallpaper = "/home/przvl/Pictures/mojavedark.jpg";
  };
}
