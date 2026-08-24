{ pkgs, resources, theme, nightMode, aiUsage, ... }:

{
  home.file.".local/share/wayle/icons/hicolor/scalable/actions/cm-ai-usage-symbolic.svg".source = resources.icons.aiUsage;
  home.file.".local/share/wayle/icons/hicolor/scalable/actions/ld-sun-symbolic.svg".source = resources.icons.night.off;
  home.file.".local/share/wayle/icons/hicolor/scalable/actions/ld-moon-symbolic.svg".source = resources.icons.night.on;
  home.file.".local/share/wayle/icons/hicolor/scalable/actions/ld-eclipse-symbolic.svg".source = resources.icons.night.plus;

  services.wayle = {
    enable = true;
    settings = {
      general = {
        font-sans = theme.font;
        font-mono = theme.font;
      };

      styling = {
        theme-provider = "wayle";
        scale = 0.85;
        rounding = "none";
        palette = {
          bg = theme.colors.background;
          surface = theme.colors.surface;
          elevated = theme.colors.elevated;
          fg = theme.colors.foreground;
          fg-muted = theme.colors.muted;
          primary = theme.colors.primary;
          red = theme.colors.red;
          yellow = theme.colors.yellow;
          green = theme.colors.green;
          blue = theme.colors.blue;
        };
      };

      bar = {
        scale = 0.75;
        padding = 0.15;
        padding-ends = 0.25;
        module-gap = 0.25;
        location = "top";
        rounding = "none";
        button-variant = "basic";
        button-bg-opacity = 0;
        button-label-size = 0.9;
        button-label-weight = "normal";
        button-label-padding = 0.25;
        button-gap = 0.4;
        button-rounding = "none";
        button-group-rounding = "none";
        layout = [
          {
            monitor = "*";
            left = [ "hyprland-workspaces" ];
            center = [ "custom-night-mode" "idle-inhibit" "separator" "clock" ];
            right = [ "custom-ai-usage" "network" "volume" "brightness" "battery" ];
          }
        ];
      };

      modules = {
        clock.format = "%a %b %d  %H:%M";
        custom = [
          {
            id = "night-mode";
            command = "${nightMode}/bin/night-mode status";
            interval-ms = 0;
            icon-map = {
              off = "ld-sun-symbolic";
              night = "ld-moon-symbolic";
              night-plus = "ld-eclipse-symbolic";
            };
            label-show = false;
            left-click = "${nightMode}/bin/night-mode next";
            on-action = "${nightMode}/bin/night-mode status";
          }
          {
            id = "ai-usage";
            command = "${aiUsage}/bin/ai-usage";
            interval-ms = 300000;
            icon-name = "cm-ai-usage-symbolic";
            label-show = false;
            tooltip-format = "{{ tooltip }}";
            left-click = "${aiUsage}/bin/ai-usage details | ${pkgs.fuzzel}/bin/fuzzel --dmenu --hide-prompt --lines=14 --width=70";
          }
        ];
        idle-inhibit = {
          label-show = false;
          left-click = "wayle idle toggle --indefinite";
        };
        # An invisible, fixed-width separator creates a clear visual break
        # between the status controls and the clock.
        separator = {
          size = 32;
          color = theme.colors.background;
        };
        network.label-show = false;
        volume.label-show = false;
        brightness.label-show = false;
        battery.label-show = false;
        hyprland-workspaces = {
          display-mode = "none";
          app-icons-show = true;
        };
        battery.thresholds = [
          {
            below = 30;
            icon-color = "yellow";
          }
          {
            below = 15;
            icon-color = "red";
            label-color = "red";
          }
        ];
      };
    };
  };

  # Stop the previous notification daemon before Wayle claims the notification bus.
  systemd.user.services.wayle.Unit.Conflicts = [ "mako.service" ];
}
