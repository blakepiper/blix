{
  description = "Blake's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Build a NixOS system from the shared Blix configuration plus the
      # host's own modules.
      mkHost = { modules, system ? "x86_64-linux" }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            home-manager.nixosModules.home-manager
          ] ++ modules;
        };
    in
    {
      nixosConfigurations = {
        t490 = mkHost { modules = [ ./hosts/t490 ]; };
      };
    };
}
