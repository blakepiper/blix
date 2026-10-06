# Stationary machines inherit the common OXWM environment and desktop defaults.
{ lib, ... }:

{
  imports = [ ../modules/common ];
  blix.machine.type = lib.mkDefault "desktop";
}
