{
  description = "Blake's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Tracks stable upstream releases independently of nixpkgs packaging.
    codex = {
      url = "github:SecBear/codex-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, codex, ... }:
    let
      overlays = [
        (import ./overlays/desktop.nix)
        codex.overlays.default
        (import ./overlays/codex.nix)
      ];
      mkHost = import ./lib/mk-host.nix { inherit nixpkgs home-manager overlays; };
    in
    {
      nixosConfigurations = {
        t490 = mkHost { modules = [ ./hosts/t490 ]; };
        zen = mkHost { modules = [ ./hosts/zen ]; };
      };

      checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
        import ./tests {
          inherit mkHost system;
          inherit (nixpkgs) lib;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );
    };
}
