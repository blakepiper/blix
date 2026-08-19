{ config, pkgs, ... }:
{
imports = [
./hardware-configuration.nix
];
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
networking.hostName = "t490";
networking.networkmanager = {
  enable = true;
  # Avoid intermittent connections caused by aggressive Wi-Fi power saving.
  wifi.powersave = false;
};
time.timeZone = "America/New_York";
nix.settings.experimental-features = [ "nix-command" "flakes" ];
home-manager.useGlobalPkgs = true;
home-manager.useUserPackages = true;
home-manager.users.przvl = import ../../home/przvl;
programs.hyprland.enable = true;

# This is a single-user machine: start the desktop directly after boot.
services.greetd = {
  enable = true;
  settings = {
    # `initial_session` starts this single-user desktop automatically once.
    initial_session = {
      command = "${pkgs.hyprland}/bin/Hyprland";
      user = "przvl";
    };

    # greetd requires a fallback session after the initial session exits.
    default_session = {
      command = "${pkgs.greetd}/bin/agreety --cmd ${pkgs.hyprland}/bin/Hyprland";
      user = "greeter";
    };
  };
};

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
services.power-profiles-daemon.enable = true;
powerManagement.enable = true;
security.pam.services.hyprlock = { };
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
nix.optimise.automatic = true;
services.logind.settings.Login = {
  HandleLidSwitch = "suspend";
  HandleLidSwitchExternalPower = "suspend";
  HandleLidSwitchDocked = "ignore";
};

users.users.przvl = {
isNormalUser = true;
extraGroups = [ "wheel" "networkmanager" ];
};

environment.systemPackages = with pkgs; [
git
vim
];

system.stateVersion = "26.05";
}
