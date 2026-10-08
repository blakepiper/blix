# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# The laptop profile supplies the shared workstation user configuration.
{ pkgs, ... }:

{
  imports = [ ./display.nix ];

  home.packages = [
    pkgs.nodejs_24
  ];
}
