{ config, lib, pkgs, ... }:

{
  options.blix.neofetch.showGpu = lib.mkEnableOption "GPU reporting in Neofetch";

  config = {
    home.packages = with pkgs; [ neofetch ];

    xdg.configFile."neofetch/config.conf".text = lib.replaceStrings
      [ "# BLIX_BATTERY_INFO" "# BLIX_GPU_INFO" ]
      [
        (lib.optionalString config.blix.hardware.hasBattery ''info "Battery" battery'')
        (lib.optionalString config.blix.neofetch.showGpu ''info "GPU" gpu'')
      ]
      (builtins.readFile ../config/neofetch/config.conf);
  };
}
