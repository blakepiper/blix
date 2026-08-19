{ pkgs, ... }:

{
home.username = "przvl";
home.homeDirectory = "/home/przvl";
home.stateVersion = "26.05";
programs.git.enable = true;
home.packages = with pkgs; [
ripgrep
fd
alacritty
nodejs
codex
brightnessctl
networkmanagerapplet
pavucontrol
wireplumber
];
wayland.windowManager.hyprland = {
  enable = true;
  configType = "lua";
  extraConfig = ''
    local main_mod = "SUPER"
    local terminal = "alacritty"

    hl.bind(main_mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
    hl.bind(main_mod .. " + Q", hl.dsp.window.close())

    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

    for workspace = 1, 3 do
      hl.bind(main_mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
      hl.bind(
        main_mod .. " + SHIFT + " .. workspace,
        hl.dsp.window.move({ workspace = workspace })
      )
    end
  '';
};

programs.waybar = {
  enable = true;
  systemd.enable = true;
  settings.mainBar = {
    layer = "top";
    position = "top";
    height = 30;
    spacing = 8;
    modules-left = [ "hyprland/workspaces" ];
    modules-center = [ "clock" ];
    modules-right = [ "network" "pulseaudio" "backlight" "battery" "tray" ];

    "hyprland/workspaces" = {
      format = "{name}";
    };

    clock = {
      format = "{:%a %b %d  %H:%M}";
      tooltip-format = "{:%Y-%m-%d}";
    };

    network = {
      format-wifi = "Wi-Fi {signalStrength}%";
      format-ethernet = "Ethernet";
      format-disconnected = "Offline";
      tooltip-format-wifi = "{essid} ({signalStrength}%)";
      on-click = "nm-connection-editor";
    };

    pulseaudio = {
      format = "Audio {volume}%";
      format-muted = "Audio muted";
      on-click = "pavucontrol";
      on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    };

    backlight = {
      format = "Brightness {percent}%";
      on-scroll-up = "brightnessctl set 5%+";
      on-scroll-down = "brightnessctl set 5%-";
    };

    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "Battery {capacity}%";
      format-charging = "Charging {capacity}%";
      format-plugged = "Plugged in {capacity}%";
      tooltip-format = "{timeToEmpty}";
    };

    tray.spacing = 8;
  };
  style = ''
    * {
      font-family: sans-serif;
      font-size: 13px;
    }

    window#waybar {
      background: #1e1e2e;
      color: #cdd6f4;
    }

    #workspaces button,
    #clock,
    #network,
    #pulseaudio,
    #backlight,
    #battery,
    #tray {
      padding: 0 8px;
    }

    #battery.warning { color: #f9e2af; }
    #battery.critical { color: #f38ba8; }
    #pulseaudio.muted,
    #network.disconnected { color: #a6adc8; }
  '';
};
}
