{ ... }:

{
  # Blix machines boot via UEFI with systemd-boot. A host that needs a
  # different bootloader can override this in its own configuration.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
