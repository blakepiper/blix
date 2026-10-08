# Shared system foundation. Profiles select their desktop environment and
# user configuration separately; this module makes no session assumptions.
{ ... }:

{
  imports = [
    ../hardware
    ./boot.nix
    ./home-manager.nix
    ./locale.nix
    ./machine.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./users.nix
  ];
}
