# INSTALLATION TEMPLATE, not detected hardware. Replace this entire file with
# nixos-generate-config --show-hardware-config after mounting the target SSD.
# Labels allow evaluation/builds now; they do not establish bootability.
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/blix-root";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = lib.mkDefault "/dev/disk/by-label/BLIX_EFI";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [ ];
}
