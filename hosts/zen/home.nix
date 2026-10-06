# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# Shared user configuration lives in home/przvl/ and is applied to every host.
{ pkgs, ... }:

{
  imports = [ ./display.nix ];

  home.packages = [
    pkgs.nodejs_24
  ];
}
