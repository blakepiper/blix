# Portable machines inherit the common OXWM environment and laptop defaults.
{ lib, ... }:

{
  imports = [ ../modules/common ];
  blix.machine.type = lib.mkDefault "laptop";
}
