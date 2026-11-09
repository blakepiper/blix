# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# The laptop profile supplies the shared workstation user configuration.
{ ... }:

{
  imports = [ ./display.nix ./xfce-dock.nix ../../home/przvl/programs/steam.nix ];

  blix.xfce.windowScalingFactor = 2;
  # The 1.6 XRandR transform blacked out the mirrored external display.
  blix.xfce.displayScale = 1.0;
}
