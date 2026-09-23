# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# Shared user configuration lives in home/przvl/ and is applied to every host.
{ pkgs, ... }:

{
  home.packages = [
    pkgs.parsec-bin
    pkgs.nodejs_24
  ];

  # Blix mirrors the external HDMI output onto the internal panel when it
  # is connected. Override these names if this Zen revision reports different
  # XRandR connectors.
  blix.display = {
    internalOutput = "eDP-1";
    externalOutput = "HDMI-1";
    # USB-C dock HDMI adapters appear as dynamically numbered DP/MST outputs.
    additionalExternalOutputs = [ "DP-*" ];
    mirrorMode = "1920x1080";
    mirrorRate = "60";
    # Keep the native 2880x1800 panel sharp while presenting a 1.75x larger
    # logical desktop when no external monitor is connected. These rounded
    # logical dimensions preserve the panel's 16:10 aspect ratio.
    internalScaleFrom = "1646x1029";
    wallpaper = "/home/przvl/Pictures/vibe.jpg";
  };
}
