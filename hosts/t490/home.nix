# ThinkPad T490 — przvl Home Manager configuration specific to this machine.
#
# Shared user configuration lives in home/przvl/ and is applied to every host.
{ ... }:

{
  blix.display = {
    internalOutput = "eDP-1";
    externalOutput = "HDMI-2";
    mirrorMode = "1920x1080";
    mirrorRate = "60";
  };
}
