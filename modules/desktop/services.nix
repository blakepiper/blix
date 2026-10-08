{ config, lib, ... }:

{
  hardware.graphics.enable = true;

  security.polkit.enable = true;
  security.rtkit.enable = true;

  # BlueZ belongs to the shared hardware policy; its GUI manager belongs to
  # the selected desktop environment.
  services.blueman.enable = lib.mkDefault config.hardware.bluetooth.enable;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };
}
