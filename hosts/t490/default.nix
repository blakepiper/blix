{ config, pkgs, ... }:
{
imports = [
./hardware-configuration.nix
];
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
networking.hostName = "t490";
networking.networkmanager.enable = true;
time.timeZone = "America/New_York";
nix.settings.experimental-features = [ "nix-command" "flakes" ];
home-manager.useGlobalPkgs = true;
home-manager.useUserPackages = true;
home-manager.users.przvl = import ../../home/przvl;
users.users.przvl = {
isNormalUser = true;
extraGroups = [ "wheel" "networkmanager" ];
};

environment.systemPackages = with pkgs; [
git
vim
];

system.stateVersion = "26.05";
}
