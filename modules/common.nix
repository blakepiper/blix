# Shared Blix system configuration.
#
# Everything here applies to every Blix machine. Anything that depends on a
# particular machine's hardware, hostname, or physical form factor belongs in
# hosts/<hostname>/ instead.
{ config, lib, pkgs, ... }:

let
  blixSddmTheme = import ./sddm-theme.nix {
    inherit pkgs;
    palette = import ../home/przvl/themes/blix.nix;
    font = (import ../home/przvl/theme.nix).font;
  };

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
  imports = [
    ./form-factor.nix
    ./laptop.nix
  ];

  # --- Nix ------------------------------------------------------------------

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "claude-code" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.optimise.automatic = true;

  # --- Boot -----------------------------------------------------------------

  # Blix machines boot via UEFI with systemd-boot. A host that needs a
  # different bootloader overrides this in its own configuration.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Locale ---------------------------------------------------------------

  time.timeZone = "America/New_York";

  # --- Networking -----------------------------------------------------------

  # The hostname is set per host in hosts/<hostname>/default.nix.
  networking.networkmanager.enable = true;

  # --- Users ----------------------------------------------------------------

  users.users.przvl = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # --- Home Manager ---------------------------------------------------------

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.przvl = import ../home/przvl;

  # --- Desktop session ------------------------------------------------------

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

  # --- Desktop services -----------------------------------------------------

  # Desktop services used by Hyprland and Waybar.
  security.polkit.enable = true;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };
  services.upower.enable = true;
  services.udisks2.enable = true;

  # --- Fonts ----------------------------------------------------------------

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "JetBrainsMono Nerd Font" ];
      serif = [ "JetBrainsMono Nerd Font" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # --- System packages ------------------------------------------------------

  environment.systemPackages = with pkgs; [
    git
    vim
  ];
}
