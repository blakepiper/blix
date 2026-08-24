{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/locale.nix
    ./modules/nix.nix
    ./modules/desktop-session.nix
    ./modules/desktop-services.nix
    ./modules/power.nix
    ./modules/users.nix
    ./modules/fonts.nix
    ./modules/packages.nix
    ./modules/home-manager.nix
  ];

  system.stateVersion = "26.05";
}
