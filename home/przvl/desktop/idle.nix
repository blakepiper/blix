{ ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = "pidof hyprlock || hyprlock";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        lock_cmd = "pidof hyprlock || hyprlock";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "pidof hyprlock || hyprlock";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
