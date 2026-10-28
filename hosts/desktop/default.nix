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

  # DDC/CI access for the external monitor brightness slider.
  hardware.i2c.enable = true;

  programs.steam.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # Use firmware/kernel sleep-state selection; do not assume ACPI S3 support.
  powerManagement.enable = true;

  # NVIDIA's suspend VT switch needs Xorg to respond. Freezing user.slice
  # first deadlocks before S3 entry (observed with the 595 open driver).
  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  # Initial installation baseline; preserve this across later upgrades.
  system.stateVersion = "26.05";
}
