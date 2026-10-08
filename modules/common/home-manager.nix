{ ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # Only identity and capability options are universal. Profiles choose the
  # workstation or phone composition through additional Home Manager imports.
  home-manager.users.przvl.imports = [ ../../home/przvl/base.nix ];
}
