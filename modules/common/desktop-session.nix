{ config, pkgs, blixSddmTheme, ... }:

let
  # Hyprland also ships an experimental UWSM entry. Blix manages its user
  # session through Home Manager, so expose only the regular entry and keep
  # the chooser to the two desktops that are actually configured.
  hyprlandSessions = pkgs.linkFarm "blix-wayland-sessions" [
    {
      name = "hyprland.desktop";
      path = "${config.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop";
    }
  ];
in
{
  programs.hyprland.enable = true;

  # Xfce is an X11 alternative to Hyprland. SDDM supplies the session chooser
  # at login and supports returning to it while the current session stays
  # locked, which is what the shared Super+L binding uses.
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
  };

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
        Users = {
          RememberLastUser = true;
          RememberLastSession = true;
        };
        Wayland.SessionDir = toString hyprlandSessions;
      };
    };
  };

  security.pam.services.hyprlock = { };
}
