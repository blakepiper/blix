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
        Restart = "on-failure";
        RestartSec = 1;
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
