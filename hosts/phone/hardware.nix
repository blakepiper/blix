# Upstream device facts and boot infrastructure; no desktop environment imports.
{ lib, pkgs, mobile-nixos, ... }:

let
  upstreamFirmware = pkgs.callPackage "${mobile-nixos}/devices/oneplus-enchilada/firmware" { };
  speakerFirmware = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/TheMuppets/proprietary_vendor_oneplus_fajita/91bb0ea54fb0870c0b3ec2bc1c584ee456206cdf/proprietary/vendor/etc/firmware/tfa98xx.cnt";
    hash = "sha256-Q99z6b1476H3jT0XHZ9a/1YeBCgdZCrAsWLsa7o2t6c=";
  };
in
{
  imports = [
    (import "${mobile-nixos}/lib/configuration.nix" { device = "oneplus-fajita"; })
  ];

  # Override the constructor's string default and Mobile's elaborated default
  # at one priority, so current nixpkgs does not try to merge both shapes.
  nixpkgs.hostPlatform = "aarch64-linux";

  # The pinned upstream firmware omits the 6T's TFA9894 speaker container.
  # Extend the same package so stage-1 and stage-2 both receive it: this built-in
  # codec requests its firmware before the persistent root is mounted.
  mobile.device.firmware = lib.mkForce (upstreamFirmware.overrideAttrs (old: {
    buildCommand = old.buildCommand + ''
      cp ${speakerFirmware} "$out/lib/firmware/tfa98xx.cnt"
    '';
  }));

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
