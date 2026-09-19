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
    mirrorMode = "1920x1080";
    mirrorRate = "60";
    wallpaper = "/home/przvl/Pictures/vibe.jpg";
  };
}
