{ config, lib, pkgs, clipboardTextProbe, hardwareHotplug, lockService, ... }:

let
  clipPath = lib.concatStringsSep ":" [
    "${clipboardTextProbe}/bin"
    "${config.home.path}/bin"
    "${pkgs.dmenu}/bin"
    "${pkgs.clipmenu}/bin"
    "${pkgs.xclip}/bin"
    "${pkgs.xsel}/bin"
    "${pkgs.coreutils}/bin"
  ];
in
{
  systemd.user.targets.blix-session = {
    Unit = {
      Description = "Blix X11 session services";
      After = [ "blix-lock.service" ];
      Wants = [
        "blix-lock.service"
        "blix-clipboard.service"
        "blix-hardware-hotplug.service"
        "blix-keyboard-repeat.service"
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
        ExecStart = "${pkgs.clipmenu}/bin/clipmenud";
        Environment = [
          "CM_SELECTIONS=clipboard"
          "CM_MAX_CLIPS=100"
          "CM_OWN_CLIPBOARD=0"
          "CM_LAUNCHER=dmenu"
          "PATH=${clipPath}"
        ];
        UMask = "0077";
      };
    };

    blix-hardware-hotplug = {
      Unit = {
        Description = "Configure external keyboard and mirrored monitor on hotplug";
        PartOf = [ "blix-session.target" ];
        After = [ "blix-lock.service" ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${hardwareHotplug}/bin/blix-hardware-hotplug";
        Environment =
          [
            "BLIX_INTERNAL_OUTPUT=${config.blix.display.internalOutput}"
            "BLIX_EXTERNAL_OUTPUT=${config.blix.display.externalOutput}"
            "BLIX_MIRROR_MODE=${config.blix.display.mirrorMode}"
            "BLIX_MIRROR_RATE=${config.blix.display.mirrorRate}"
          ]
          ++ lib.optional (config.blix.display.internalScaleFrom != null)
            "BLIX_INTERNAL_SCALE_FROM=${config.blix.display.internalScaleFrom}"
          ++ lib.optional (config.blix.display.wallpaper != null)
            "BLIX_WALLPAPER=${config.blix.display.wallpaper}";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    # The X server flags and .xinitrc cover new sessions. Reapply the same
    # setting from a user service as well because Home Manager can reload the
    # session units during a rebuild without restarting the manually started
    # X server.
    blix-keyboard-repeat = {
      Unit = {
        Description = "Configure fast X11 keyboard repeat";
        ConditionEnvironment = "DISPLAY";
        PartOf = [ "blix-session.target" ];
        After = [ "blix-hardware-hotplug.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.xset}/bin/xset r rate 200 50";
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
        ExecStart = "${pkgs.picom}/bin/picom --config ${config.home.homeDirectory}/.config/picom/picom.conf";
      };
    };
  };
}
