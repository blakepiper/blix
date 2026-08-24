{ ... }:

{
  networking.hostName = "t490";
  networking.networkmanager = {
    enable = true;
    # Avoid intermittent connections caused by aggressive Wi-Fi power saving.
    wifi.powersave = false;
  };
}
