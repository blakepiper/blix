# How a host describes the kind of machine it is.
#
# `blix.formFactor` is mirrored into the przvl Home Manager configuration so
# user-level settings can branch on the machine class rather than its hostname.
{ config, lib, ... }:

{
  options.blix.formFactor = lib.mkOption {
    type = lib.types.enum [ "laptop" "desktop" ];
    description = ''
      What kind of machine this host is. Every host must set this; there is
      deliberately no default, so a new machine has to make the choice.
    '';
    example = "laptop";
  };

  config.home-manager.users.przvl.blix.formFactor = config.blix.formFactor;
}
