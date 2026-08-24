{ ... }:
{
imports = [
../../modules/common
../../modules/laptop
./hardware-configuration.nix
];
networking.hostName = "zen";
blix.formFactor = "laptop";
home-manager.users.przvl = import ./home.nix;
system.stateVersion = "26.05";
}
