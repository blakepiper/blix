{ lib, ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "(12, 36)";
        width = "(180, 360)";
        notification_limit = 3;
        font = "monospace 11";
        frame_color = "#98c379";
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
      PartOf = lib.mkForce [ "blix-session.target" ];
    };
    Install.WantedBy = [ "blix-session.target" ];
  };
  systemd.user.targets.blix-session.Unit.Wants = [ "dunst.service" ];
}
