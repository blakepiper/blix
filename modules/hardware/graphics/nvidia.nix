# Single-GPU NVIDIA desktops (Turing and newer); import explicitly per host.
{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    modesetting.enable = true;
    # Preserve the graphical session's VRAM through suspend. NixOS selects
    # systemd sleep services or kernel notifiers to match the pinned driver.
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    # No additional NVIDIA GUI application; shared Blix settings remain in use.
    nvidiaSettings = false;
    # ext4 supports unnamed temporary files; avoid a RAM-backed /tmp for 8 GiB VRAM.
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
  };
}
