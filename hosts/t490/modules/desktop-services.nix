{ ... }:

{
  # Desktop services used by Hyprland and Waybar.
  security.polkit.enable = true;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };
  services.upower.enable = true;
  services.udisks2.enable = true;
  services.power-profiles-daemon.enable = true;
}
