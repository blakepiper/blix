{ ... }:

{
  # Hostnames and device-specific workarounds stay under hosts/<hostname>/.
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;
}
