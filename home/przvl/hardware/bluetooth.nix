{ config, lib, ... }:

{
  services.blueman-applet = {
    enable = config.blix.hardware.hasBluetooth;
    systemdTargets = [ "blix-session.target" ];
  };

  # Use notification bubbles instead of Blueman's focus-taking GTK fallback.
  dconf.settings."org/blueman/general" = lib.mkIf config.services.blueman-applet.enable {
    notification-daemon = true;
  };

  # OXWM has no tray target. Keep the pairing agent with the manual X11
  # session, without waiting for a tray or ordering it after its own target.
  systemd.user.services.blueman-applet = lib.mkIf config.services.blueman-applet.enable {
    Unit.Requires = lib.mkForce [ ];
    Unit.After = lib.mkForce [ "blix-lock.service" "dunst.service" ];
    Unit.Wants = [ "dunst.service" ];
  };
  systemd.user.targets.blix-session.Unit.Wants =
    lib.optional config.services.blueman-applet.enable "blueman-applet.service";
}
