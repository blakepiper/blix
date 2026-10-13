{ pkgs, clipboardTextProbe, lockService, blixSettings,
  blixSessionSettings, ... }:

let
  # clipmenud's package wrapper replaces PATH, so a service PATH cannot
  # interpose the image-safe probe. Override its actual xsel dependency.
  clipboardHistory = pkgs.clipmenu.override { xsel = clipboardTextProbe; };
in
{
  systemd.user.targets.blix-session = {
    Unit = {
      Description = "Blix X11 session services";
      After = [ "blix-lock.service" ];
      Wants = [
        "blix-lock.service"
        "blix-clipboard.service"
        "blix-session-settings.service"
        "blix-picom.service"
        "pipewire.socket"
        "pipewire-pulse.socket"
        "wireplumber.service"
      ];
    };
  };

  systemd.user.services = {
    blix-lock = {
      Unit = {
        Description = "Lock X11 on logind suspend and explicit lock requests";
        PartOf = [ "blix-session.target" ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${lockService}";
        Environment = [ "XSECURELOCK_SAVER=saver_blank" ];
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    blix-clipboard = {
      Unit = {
        Description = "Event-driven text clipboard history";
        PartOf = [ "blix-session.target" ];
        After = [ "blix-lock.service" ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${clipboardHistory}/bin/clipmenud";
        Environment = [
          "CM_SELECTIONS=clipboard"
          "CM_MAX_CLIPS=100"
          "CM_OWN_CLIPBOARD=0"
          "CM_LAUNCHER=dmenu"
        ];
        UMask = "0077";
      };
    };

    # Reapply settings when Home Manager reloads an already-running session.
    blix-session-settings = {
      Install.WantedBy = [ "blix-session.target" ];
      Unit = {
        Description = "Configure X11 keyboard repeat, display blanking and font DPI";
        ConditionEnvironment = "DISPLAY";
        PartOf = [ "blix-session.target" ];
        After = [ "blix-display-hotplug.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${blixSessionSettings}/bin/blix-session-settings";
        RemainAfterExit = true;
      };
    };

    blix-picom = {
      Unit = {
        Description = "Picom compositor for the Blix X11 session";
        PartOf = [ "blix-session.target" ];
        After = [ "blix-lock.service" ];
      };
      Service = {
        Type = "exec";
        ExecStartPre = "${blixSettings}/bin/blix-settings-apply prepare-picom";
        ExecStart = "${pkgs.picom}/bin/picom --config %t/blix-settings-%U/picom.conf";
      };
    };
  };
}
