{ config, lib, ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "(12, 36)";
        width = "(180, 360)";
        notification_limit = 3;
        font = "JetBrainsMono Nerd Font 11";
        frame_color = "#7aa2f7";
        show_indicators = false;
      };
      urgency_low = {
        background = "#1a1b26";
        foreground = "#a9b1d6";
        frame_color = "#292e42";
      };
      urgency_normal = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        frame_color = "#7aa2f7";
      };
      urgency_critical = {
        background = "#1a1b26";
        foreground = "#f7768e";
        frame_color = "#f7768e";
      };
      # Terminal completion messages should be brief even with a client timeout.
      ghostty = lib.hm.dag.entryAfter [ "global" ] {
        appname = "ghostty";
        override_dbus_timeout = "3s";
      };
      # Blueman uses the default (-1) timeout for connection status, including
      # AutoConnect. Pairing/authorization requests use 0 and must stay actionable.
      bluetooth-status = lib.hm.dag.entryAfter [ "global" ] {
        appname = "blueman";
        icon_position = "off";
        timeout = "2s";
        set_transient = true;
        history_ignore = true;
      };
    };
  };

  systemd.user.services.dunst = {
    Unit = {
      After = lib.mkForce [ "blix-lock.service" ];
      PartOf = lib.mkForce ([ "blix-session.target" ]
        ++ lib.optional (config.systemd.user.targets ? blix-wayland-session) "blix-wayland-session.target");
    };
    Install.WantedBy = [ "blix-session.target" ];
  };
  systemd.user.targets.blix-session.Unit.Wants = [ "dunst.service" ];
}
