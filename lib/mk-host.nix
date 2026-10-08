# Package policy and Home Manager integration are shared by every host.
{ nixpkgs, home-manager, overlays }:

{ modules, system ? "x86_64-linux", specialArgs ? { } }:
nixpkgs.lib.nixosSystem {
  inherit specialArgs;
  modules = [
    {
      nixpkgs.hostPlatform = nixpkgs.lib.mkDefault system;
      nixpkgs.overlays = overlays;
    }
    home-manager.nixosModules.home-manager
  ] ++ modules;
}
