# How a host describes the kind of machine it is.
#
# `blix.formFactor` is the single switch hosts use to opt into machine-class
# behavior. It selects modules/laptop.nix on the system side and is mirrored
# into the przvl Home Manager configuration so user-level settings can branch
# on it too, rather than testing the hostname.
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
