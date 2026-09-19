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
      # Blix pins OXWM 0.13.0 rather than the older release currently packaged
      # by nixpkgs. Keep its two reviewed patches
      # in-tree so the X11 session has the same microphone key and mirrored
      # monitor behavior as the Arch setup.
      blixOverlay = final: prev: {
        oxwm = prev.oxwm.overrideAttrs (old: {
          version = "0.13.0";
          src = final.fetchFromGitHub {
            owner = "tonybanters";
            repo = "oxwm";
            rev = "fc4ada9ac4ee8e34ace203290a2b14d10e4671cc";
            hash = "sha256-PnEF4Qus7h0Wyr9U8mhQ83uWxfz6VUZ99I1YJgjUK6w=";
          };
          patches = (old.patches or [ ]) ++ [
            ./packaging/oxwm/0001-microphone-keysym.patch
            ./packaging/oxwm/0002-unique-mirrored-screens.patch
          ];
        });

        "st-blix" =
          let
            stWithConfig = prev.st.override {
              conf = builtins.readFile ./packaging/st/config.h;
              patches = [ ./packaging/st/0001-scrollback-and-urls.patch ];
            };
          in
          stWithConfig.overrideAttrs (old: {
            # The current st expression concatenates its postPatch snippets
            # without a separator when a custom config is supplied.
            postPatch = nixpkgs.lib.replaceStrings
              [ "config.def.hsubstituteInPlace" ]
              [ "config.def.h\nsubstituteInPlace" ]
              old.postPatch;
          });
      };

      # Home Manager supplies NixOS module options used by the shared Blix
      # configuration. Each host explicitly composes its shared, hardware, and
      # host-specific modules.
      mkHost = { modules, system ? "x86_64-linux" }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            { nixpkgs.overlays = [ blixOverlay ]; }
            home-manager.nixosModules.home-manager
          ] ++ modules;
        };
    in
    {
      nixosConfigurations = {
        t490 = mkHost { modules = [ ./hosts/t490 ]; };
        zen = mkHost { modules = [ ./hosts/zen ]; };
      };
    };
}
