# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# The laptop profile supplies the shared workstation user configuration.
{ ... }:

{
  imports = [ ./display.nix ./xfce-dock.nix ../../home/przvl/programs/steam.nix ];

  blix.xfce.windowScalingFactor = 2;
  # 2x window scaling divided by this display scale gives 125% overall.
  blix.xfce.displayScale = 1.6;
}
