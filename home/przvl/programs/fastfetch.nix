{ config, lib, ... }:

let
  settings = builtins.fromJSON (builtins.readFile ../config/fastfetch/config.jsonc);
in
{
  programs.fastfetch = {
    enable = true;
    settings = settings // {
      modules = lib.filter (module:
        config.blix.hardware.hasBattery
        || !((builtins.isAttrs module && (module.type or "") == "battery") || module == "poweradapter")
      ) settings.modules;
    };
  };
}
