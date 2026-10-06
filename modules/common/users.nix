{ pkgs, ... }:

{
  users.users.przvl = {
    isNormalUser = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
