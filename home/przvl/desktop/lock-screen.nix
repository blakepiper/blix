{ config, pkgs, ... }:

{
  # hyprlock.conf itself is supplied by the active theme; see themes/.
  programs.hyprlock.enable = true;

  # The one way this session gets locked. Blix runs a single Hyprland desktop,
  # so locking never hands the display to anything else: no VT switch, no
  # greeter, and therefore no modeset that the display could hang on. Reuse a
  # running hyprlock rather than stacking a second instance over the first.
  _module.args.lockCommand =
    "${pkgs.procps}/bin/pidof hyprlock || ${config.programs.hyprlock.package}/bin/hyprlock";
}
