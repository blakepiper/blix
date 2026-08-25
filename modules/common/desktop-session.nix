{ config, pkgs, blixSddmTheme, ... }:

let
  # Hyprland also ships an experimental UWSM entry. Blix manages its user
  # session through Home Manager, so expose only the regular entry.
  hyprlandSessions = pkgs.linkFarm "blix-wayland-sessions" [
    {
      name = "hyprland.desktop";
      path = "${config.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop";
    }
  ];
in
{
  programs.hyprland.enable = true;

  # Hyprland is the only desktop Blix offers, so the session directory below is
  # the only thing SDDM can log in to. X11 itself stays enabled purely because
  # SDDM's greeter runs on it; no X11 desktop session is installed.
  services.xserver.enable = true;

  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      theme = toString blixSddmTheme;
      extraPackages = with pkgs.kdePackages; [
        qtmultimedia
        qtsvg
        qtvirtualkeyboard
      ];
      settings = {
        Users.RememberLastUser = true;
        Wayland.SessionDir = toString hyprlandSessions;
      };
    };
  };

  security.pam.services.hyprlock = { };
}
