# Small first-install userspace sharing the real hardware and temporary access
# modules. The finished host remains profiles/phone.nix's regular Xorg/OXWM.
{ pkgs, ... }:

{
  imports = [
    ../../profiles/phone.nix
    ./hardware.nix
    ./bootstrap.nix
  ];
  disabledModules = [ ../../modules/desktop ../../modules/common/packages.nix ];
  home-manager.users.przvl = {
    disabledModules = [ ../../home/przvl/phone.nix ];
    programs.bash.enable = true;
  };

  networking.hostName = "phone";
  system.stateVersion = "26.11";

  # Keep installation small: SSH/Nix/BlueZ are installed by their modules.
  # The full phone host still selects the normal Blix command-line packages.
  environment.defaultPackages = [ ];
  environment.systemPackages = with pkgs; [ git ];
  documentation.enable = false;
}
