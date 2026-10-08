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
    # Device, kernel, firmware and Android boot-image support only.
    mobile-nixos = {
      url = "github:mobile-nixos/mobile-nixos";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, codex, mobile-nixos, ... }:
    let
      overlays = [
        (import ./overlays/desktop.nix)
        codex.overlays.default
        (import ./overlays/codex.nix)
      ];
      mkHost = import ./lib/mk-host.nix { inherit nixpkgs home-manager overlays; };
      phone = mkHost {
        system = "aarch64-linux";
        specialArgs = { inherit mobile-nixos; };
        modules = [ ./hosts/phone ];
      };
      phoneBootstrap = buildSystem: mkHost {
        system = "aarch64-linux";
        specialArgs = { inherit mobile-nixos; };
        modules = [
          ./hosts/phone/bootstrap-system.nix
          { nixpkgs.buildPlatform = buildSystem; }
        ];
      };
    in
    {
      nixosConfigurations = {
        t490 = mkHost { modules = [ ./hosts/t490 ]; };
        zen = mkHost { modules = [ ./hosts/zen ]; };
        inherit phone;
      };

      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        # On x86 this cross-compiles only the small bootstrap, not the desktop.
        phone-bootstrap-images = (phoneBootstrap system).config.mobile.outputs.android.android-fastboot-images;
      } // nixpkgs.lib.optionalAttrs (system == "aarch64-linux") {
        phone-boot-image = phone.config.mobile.outputs.android.android-bootimg;
        phone-fastboot-images = phone.config.mobile.outputs.android.android-fastboot-images;
      });

      checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
        import ./tests {
          inherit mkHost system phone phoneBootstrap;
          inherit (nixpkgs) lib;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );
    };
}
