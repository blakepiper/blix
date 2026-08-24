# ThinkPad T490 — host-specific configuration.
#
# Shared Blix configuration lives in modules/common.nix and is added by
# flake.nix. Only settings that depend on this machine belong here.
{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Home Manager settings that depend on this machine, merged with the
  # shared home/przvl configuration applied in modules/common.nix.
  home-manager.users.przvl = import ./home.nix;

  networking.hostName = "t490";

  # This laptop's Wi-Fi adapter drops connections intermittently with
  # aggressive power saving enabled.
  networking.networkmanager.wifi.powersave = false;

  # --- Laptop power management ----------------------------------------------

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  # Prefer maximum responsiveness when the laptop is on AC power.
  systemd.services.power-profile-performance-ac = {
    description = "Select the performance power profile on AC power";
    after = [ "power-profiles-daemon.service" ];
    wants = [ "power-profiles-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/sys/class/power_supply/AC/online";
    serviceConfig = {
      Type = "oneshot";
      ExecCondition = "${pkgs.writeShellScript "check-ac-power" ''
        test "$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC/online)" = 1
      ''}";
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="AC", ACTION=="change", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="power-profile-performance-ac.service"
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # The NixOS release this machine was installed with. Per host; never copied
  # to a new machine.
  system.stateVersion = "26.05";
}
