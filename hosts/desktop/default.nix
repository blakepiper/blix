# Ryzen 5 5600X / RTX 3070 workstation.
{ lib, ... }:

{
  imports = [
    ../../profiles/desktop.nix
    ./hardware-configuration.nix
    ../../modules/hardware/graphics/nvidia.nix
  ];

  networking.hostName = "desktop";
  home-manager.users.przvl = import ./home.nix;

  # Proprietary NVIDIA userspace and Steam are explicitly selected on this host.
  nixpkgs.config.allowUnfreePredicate = package:
    builtins.elem (lib.getName package) [
      "nvidia-x11" "nvidia-settings" "nvidia-persistenced"
      "steam" "steam-original" "steam-unwrapped" "steam-run"
    ];

  programs.steam.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # Use firmware/kernel sleep-state selection; do not assume ACPI S3 support.
  powerManagement.enable = true;

  # Initial installation baseline; preserve this across later upgrades.
  system.stateVersion = "26.05";
}
