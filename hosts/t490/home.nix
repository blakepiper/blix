# ThinkPad T490 — przvl Home Manager configuration specific to this machine.
#
# Shared user configuration lives in home/przvl/ and is applied to every host.
{ ... }:

{
  blix.monitors = [
    {
      output = "eDP-1";
      mode = "1920x1080@60.008";
      position = "0x0";
      scale = 1.25;
    }
    {
      output = "HDMI-A-2";
      mode = "3840x2160@30";
      position = "-2560x0";
      scale = 1.5;
    }
  ];
}
