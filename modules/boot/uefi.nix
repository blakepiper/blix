# Conventional UEFI machines inherit this; other boot providers choose their
# own loader. Defaults can be overridden without mkForce.
{ lib, ... }:

{
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
