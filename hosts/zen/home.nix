# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# The laptop profile supplies the shared workstation user configuration.
{ lib, ... }:

{
  imports = [ ./display.nix ../../home/przvl/programs/steam.nix ];

  programs.ghostty.settings.font-size = lib.mkForce 22;
}
