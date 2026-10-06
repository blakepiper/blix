{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [ neofetch ];

  xdg.configFile."neofetch/config.conf".text = lib.replaceStrings
    [ "# BLIX_BATTERY_INFO" ]
    [ (lib.optionalString config.blix.hardware.hasBattery ''info "Battery" battery'') ]
    (builtins.readFile ../config/neofetch/config.conf);
}
