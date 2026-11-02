# Optional Steam integration and the Proton/OXWM game-focus workaround.
{ lib, pkgs, ... }:

{
  programs.steam = {
    enable = true;
    # Steam and its overlay query PulseAudio even when PipeWire supplies it.
    extraPackages = with pkgs; [ pulseaudio ];
  };

  # Hosts with additional proprietary packages can supply a broader predicate.
  nixpkgs.config.allowUnfreePredicate = lib.mkDefault (package:
    builtins.elem (lib.getName package) [
      "steam" "steam-original" "steam-unwrapped" "steam-run"
    ]);

  nixpkgs.overlays = [
    (final: prev: {
      oxwm = prev.oxwm.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./oxwm-steam-focus.patch ];
      });
    })
  ];
}
