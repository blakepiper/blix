# Steam integration and the observed Proton/OXWM focus workaround on Desktop.
{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    # Steam and its overlay query PulseAudio even when PipeWire supplies it.
    extraPackages = with pkgs; [ pulseaudio ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      oxwm = prev.oxwm.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./oxwm-steam-focus.patch ];
      });
    })
  ];
}
