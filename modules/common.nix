# Shared Blix system configuration.
#
# Everything here applies to every Blix machine. Anything that depends on a
# particular machine's hardware, hostname, or physical form factor belongs in
# hosts/<hostname>/ instead.
{ config, lib, pkgs, ... }:

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

  # Start a login prompt at boot, then launch Hyprland after authentication.
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd ${config.programs.hyprland.package}/bin/start-hyprland";
      user = "greeter";
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
