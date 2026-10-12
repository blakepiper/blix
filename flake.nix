{
  description = "Blake's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Official stable release bundles; refreshed by nix flake update.
    codex-x86_64 = {
      type = "tarball";
      url = "https://github.com/openai/codex/releases/latest/download/codex-package-x86_64-unknown-linux-musl.tar.gz";
      flake = false;
    };
    codex-aarch64 = {
      type = "tarball";
      url = "https://github.com/openai/codex/releases/latest/download/codex-package-aarch64-unknown-linux-musl.tar.gz";
      flake = false;
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

  outputs = { nixpkgs, home-manager, codex-x86_64, codex-aarch64, mobile-nixos, ... }:
    let
      overlays = [
        (import ./overlays/desktop.nix)
        (import ./overlays/codex.nix {
          releases = {
            x86_64-linux = codex-x86_64;
            aarch64-linux = codex-aarch64;
          };
        })
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
        codex = (import nixpkgs { inherit system overlays; }).codex;
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
