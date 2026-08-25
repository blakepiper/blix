{ pkgs, lockCommand, ... }:

let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = lockCommand;
        after_sleep_cmd = "${hyprctl} dispatch dpms on";
        lock_cmd = lockCommand;
      };
      listener = [
        {
          timeout = 300;
          on-timeout = lockCommand;
        }
        {
          timeout = 600;
          on-timeout = "${hyprctl} dispatch dpms off";
          on-resume = "${hyprctl} dispatch dpms on";
        }
      ];
    };
  };
}
