{ config, lib, pkgs, ... }:

let
  helpers = import ./scripts/hyprland.nix { inherit config lib pkgs; };
  target = "blix-hyprland-session.target";
  service = description: command: {
    Unit = {
      Description = description;
      PartOf = [ target ];
      After = [ target ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Install.WantedBy = [ target ];
    Service = {
      ExecStart = command;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
in
{
  home.packages = builtins.attrValues helpers;

  # NixOS owns the compositor and portal packages. The TTY wrapper owns
  # session lifetime so cleanup also happens after an abnormal compositor exit.
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
    systemd.enable = false;
    extraConfig = let substitutions = {
      internalOutput = config.blix.wayland.internalOutput;
      internalScale = toString config.blix.wayland.internalScale;
      mirrorMode = "${config.blix.display.mirrorMode}@${config.blix.display.mirrorRate}";
      foot = "${pkgs.foot}/bin/foot";
      fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
      firefox = "${config.programs.firefox.finalPackage}/bin/firefox";
      xfe = "${pkgs.xfe}/bin/xfe";
      wpctl = "${pkgs.wireplumber}/bin/wpctl";
      playerctl = "${pkgs.playerctl}/bin/playerctl";
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
      session = "${helpers.session}/bin/blix-hyprland-session";
      lock = "${helpers.lock}/bin/blix-hyprland-lock";
      clipboard = "${helpers.clipboard}/bin/blix-hyprland-clipboard";
      screenshot = "${helpers.screenshot}/bin/blix-hyprland-screenshot";
      control = "${helpers.control}/bin/blix-hyprland-control";
    };
    in lib.replaceStrings
      (map (name: "@${name}@") (builtins.attrNames substitutions))
      (builtins.attrValues substitutions)
      (builtins.readFile ./config/hypr/hyprland.lua);
  };

  programs.foot = {
    enable = true;
    server.enable = false;
    settings = {
      main = { font = "JetBrainsMono Nerd Font:size=11"; pad = "2x2"; };
      colors-dark = {
        background = "1a1b26";
        foreground = "bbbbbb";
        regular0 = "1a1b26";
        regular1 = "cd0000";
        regular2 = "00cd00";
        regular3 = "cdcd00";
        regular4 = "0000ee";
        regular5 = "cd00cd";
        regular6 = "00cdcd";
        regular7 = "bbbbbb";
        bright0 = "7f7f7f";
        bright1 = "ff0000";
        bright2 = "00ff00";
        bright3 = "ffff00";
        bright4 = "5c5cff";
        bright5 = "ff00ff";
        bright6 = "00ffff";
        bright7 = "ffffff";
      };
      scrollback.lines = 10000;
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = { font = "JetBrainsMono Nerd Font:size=10"; terminal = "${pkgs.foot}/bin/foot"; };
      colors = {
        background = "1a1b26ff";
        text = "bbbbbbff";
        match = "9fe3c4ff";
        selection = "34324aff";
        selection-text = "d7ffe8ff";
        border = "9fe3c4ff";
      };
      border = { width = 2; radius = 0; };
    };
  };

  programs.waybar = {
    enable = true;
    systemd.enable = false;
    settings.main = {
      layer = "top";
      position = "top";
      height = 24;
      modules-left = [ "hyprland/workspaces" ];
      modules-right = [ "battery" "memory" "cpu" "clock" ];
      "hyprland/workspaces" = {
        "persistent-workspaces"."*" = 9;
        "disable-scroll" = true;
        "on-click" = "activate";
      };
      battery = { interval = 30; format = "Bat: {capacity}% {time}"; "format-charging" = "Bat: {capacity}% +"; };
      memory = { interval = 5; format = "Ram: {used:0.1f}/{total:0.1f} GB"; };
      cpu = { interval = 5; format = "CPU: {usage}%"; };
      clock = { interval = 60; format = "{:%a, %b %d - %H:%M}"; };
    };
    style = ''
      * { font-family: "JetBrainsMono Nerd Font"; font-size: 13px; border-radius: 0; min-height: 0; }
      window#waybar { background: #1a1b26; color: #bbbbbb; }
      #workspaces button { padding: 0 7px; color: #6ee7a0; border: 0; }
      #workspaces button.empty { color: #bbbbbb; }
      #workspaces button.active { color: #9fe3c4; box-shadow: inset 0 -2px #d7ffe8; }
      #workspaces button.urgent { color: #f7768e; }
      #battery, #memory, #cpu, #clock { padding: 0 8px; border-left: 1px solid #bb9af7; }
      #battery { color: #9ece6a; }
      #memory { color: #7aa2f7; }
      #cpu { color: #e0af68; }
      #clock { color: #0db9d7; }
    '';
  };

  programs.hyprlock = {
    enable = true;
    package = null; # Installed by the NixOS module, including PAM setup.
    settings = {
      general = { hide_cursor = true; immediate_render = true; };
      animations.enabled = false;
      background = [{ monitor = ""; color = "rgb(1a1b26)"; }];
      input-field = [{
        monitor = "";
        size = "300, 50";
        outline_thickness = 2;
        rounding = 0;
        outer_color = "rgb(9fe3c4)";
        inner_color = "rgb(1a1b26)";
        font_color = "rgb(bbbbbb)";
        placeholder_text = "Password";
      }];
    };
  };

  services.hypridle = {
    enable = true;
    systemdTarget = target;
    # No idle listeners: manual locking and lock-before-suspend only.
    settings.general = {
      lock_cmd = "${helpers.lock}/bin/blix-hyprland-lock";
      before_sleep_cmd = "${helpers.lock}/bin/blix-hyprland-lock";
      after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({action=\"on\"})'";
      inhibit_sleep = 3;
    };
  };

  systemd.user.targets.blix-hyprland-session.Unit.Description = "Blix Hyprland session helpers";
  systemd.user.services = {
    blix-hyprland-bar = service "Blix Wayland status bar" "${pkgs.waybar}/bin/waybar";
    blix-hyprland-wallpaper = service "Blix Wayland background" "${helpers.wallpaper}/bin/blix-hyprland-wallpaper";
    blix-hyprland-clipboard = lib.recursiveUpdate
      (service "Blix Wayland text clipboard history"
        "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist --max-items 100 store")
      { Service.UMask = "0077"; };
  };
}
