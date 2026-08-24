# Power behavior tied to the ThinkPad T490's AC power-supply device.
{ pkgs, ... }:

{
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
}
