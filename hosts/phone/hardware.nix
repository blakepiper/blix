# Upstream device facts and boot infrastructure; no desktop environment imports.
{ lib, pkgs, mobile-nixos, ... }:

{
  imports = [
    (import "${mobile-nixos}/lib/configuration.nix" { device = "oneplus-fajita"; })
  ];

  # Override the constructor's string default and Mobile's elaborated default
  # at one priority, so current nixpkgs does not try to merge both shapes.
  nixpkgs.hostPlatform = "aarch64-linux";

  nixpkgs.config.allowUnfreePredicate = package:
    builtins.elem (lib.getName package) [
      "oneplus-sdm845-firmware"
      "oneplus-sdm845-firmware-zstd"
    ];

  # Installation target, matching the fajita Phoneputer workflow. The image
  # supplies NIXOS_SYSTEM's ext4 label; no detected UUID or PC /boot is invented.
  mobile.system.android.system_partition_destination = "userdata";
  # Keep the Android GPT layout. Only the filesystem grows within userdata.
  boot.growPartition = false;

  # fajita has no stage-0/kexec support. A rebuild updates the userspace profile;
  # boot.img/kernel/initrd updates require a separate, approved installation.
  boot.loader.external = {
    enable = true;
    installHook = pkgs.writeShellScript "phone-external-boot-loader" ''
      echo 'Phone userspace profile updated; Android boot partitions are managed separately.' >&2
    '';
  };
}
