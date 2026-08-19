{ config, pkgs, ... }:

let
  lakesAndLightWallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/mattbbia/lakes-and-light/1c14ea7b3fbb0bc8bd7097c74261e65affdc712b/backgrounds/lake-albano-1790-1792.jpg";
    hash = "sha256-iOBqjWHqqPaTNbFfKryBRF+P3A0MLSjqlYrH6sr5iqk=";
  };

  togglePowerProfile = pkgs.writeShellScript "toggle-power-profile" ''
    if [ "$(${pkgs.power-profiles-daemon}/bin/powerprofilesctl get)" = "power-saver" ]; then
      next_profile="balanced"
    else
      next_profile="power-saver"
    fi

    exec ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$next_profile"
  '';
in

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
fuzzel
nautilus
file-roller
ffmpegthumbnailer
vscodium
python3
uv
btop
grim
slurp
wl-clipboard
zip
unzip
p7zip
noto-fonts
noto-fonts-color-emoji
nerd-fonts.jetbrains-mono
];

programs.firefox = {
  enable = true;
  policies.ExtensionSettings."uBlock0@raymondhill.net" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
    installation_mode = "force_installed";
    private_browsing = true;
  };
};

programs.fastfetch = {
  enable = true;
  settings.logo = {
    source = "nixos_small";
    padding.right = 1;
  };
};

programs.hyprlock = {
  enable = true;
  settings = {
    general = {
      hide_cursor = true;
      ignore_empty_input = true;
    };
    background = [
      {
        path = "screenshot";
        blur_passes = 3;
        blur_size = 8;
      }
    ];
    "input-field" = [
      {
        size = "240, 54";
        position = "0, -80";
        monitor = "";
        dots_center = true;
        fade_on_empty = false;
        font_color = "rgb(3a1911)";
        inner_color = "rgba(f5e4d8aa)";
        outer_color = "rgb(563819)";
        outline_thickness = 3;
        placeholder_text = "<i>Password...</i>";
      }
    ];
  };
};

services.cliphist = {
  enable = true;
  allowImages = true;
  extraOptions = [
    "-max-dedupe-search"
    "10"
    "-max-items"
    "100"
  ];
};

services.wl-clip-persist.enable = true;

services.hypridle = {
  enable = true;
  settings = {
    general = {
      before_sleep_cmd = "pidof hyprlock || hyprlock";
      after_sleep_cmd = "hyprctl dispatch dpms on";
      lock_cmd = "pidof hyprlock || hyprlock";
    };
    listener = [
      {
        timeout = 300;
        on-timeout = "pidof hyprlock || hyprlock";
      }
      {
        timeout = 600;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on";
      }
    ];
  };
};

services.mako = {
  enable = true;
  settings = {
    text-color = "#3a1911";
    border-color = "#563819";
    background-color = "#f5e4d8";
    width = 420;
    height = 110;
    padding = 10;
    border-size = 2;
    font = "JetBrainsMono Nerd Font 11";
    anchor = "top-right";
    outer-margin = 20;
    default-timeout = 5000;
    max-icon-size = 32;
  };
};

services.hyprpaper = {
  enable = true;
  settings = {
    splash = false;
    wallpaper = [
      {
        monitor = "";
        path = "${lakesAndLightWallpaper}";
        fit_mode = "cover";
      }
    ];
  };
};

programs.alacritty = {
  enable = true;
  settings.colors = {
    primary = {
      background = "#f5e4d8";
      foreground = "#3a1911";
    };
    normal = {
      black = "#f5e4d8";
      red = "#562b00";
      green = "#653e00";
      yellow = "#7b5521";
      blue = "#805f36";
      magenta = "#563819";
      cyan = "#875c26";
      white = "#3a1911";
    };
    bright = {
      black = "#7f7974";
      red = "#7c4b14";
      green = "#8b5f0f";
      yellow = "#a27832";
      blue = "#a7824b";
      magenta = "#7b582f";
      cyan = "#af7f36";
      white = "#5e362b";
    };
    cursor = {
      text = "#f5e4d8";
      cursor = "#3a1911";
    };
  };
};

programs.fuzzel = {
  enable = true;
  settings.colors = {
    background = "f5e4d8ff";
    text = "3a1911ff";
    match = "805f36ff";
    selection = "805f36ff";
    selection-text = "f5e4d8ff";
    selection-match = "f5e4d8ff";
    border = "563819ff";
  };
};

home.pointerCursor = {
  enable = true;
  package = pkgs.everforest-cursors;
  name = "everforest-cursors-light";
  size = 32;
  gtk.enable = true;
  x11.enable = true;
};

gtk = {
  enable = true;
  colorScheme = "light";
  gtk3.extraCss = ''
    @define-color theme_bg_color #f5e4d8;
    @define-color theme_fg_color #3a1911;
    @define-color theme_selected_bg_color #805f36;
    @define-color theme_selected_fg_color #f5e4d8;
    @define-color borders alpha(#3a1911, 0.15);
    selection { background-color: #805f36; color: #f5e4d8; }
  '';
  gtk4.extraCss = ''
    @define-color window_bg_color #f5e4d8;
    @define-color window_fg_color #3a1911;
    @define-color accent_bg_color #805f36;
    @define-color accent_fg_color #f5e4d8;
    @define-color borders alpha(#3a1911, 0.15);
    selection { background-color: #805f36; color: #f5e4d8; }
  '';
};

services.udiskie = {
  enable = true;
  automount = true;
  notify = true;
};

systemd.user.services = {
  mako = {
    Unit = {
      Description = "Mako notification daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.mako}/bin/mako";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  polkit-gnome-authentication-agent = {
    Unit = {
      Description = "Polkit authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
};

wayland.windowManager.hyprland = {
  enable = true;
  configType = "lua";
  extraConfig = ''
    local main_mod = "SUPER"
    local terminal = "alacritty"

    local function snap_focused_window(x, y, width, height)
      return function()
        local window = hl.get_active_window()
        if not window or not window.monitor then return end

        local monitor = window.monitor
        hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
        hl.dispatch(hl.dsp.window.resize({
          x = monitor.width * width,
          y = monitor.height * height,
          window = window,
        }))
        hl.dispatch(hl.dsp.window.move({
          x = monitor.x + monitor.width * x,
          y = monitor.y + monitor.height * y,
          window = window,
        }))
      end
    end

    hl.config({
      monitor = {
        "eDP-1,1920x1080@60.008,0x0,1.25",
        "HDMI-A-2,2560x1440@59.95,1536x0,1.5",
      },
      input = {
        natural_scroll = true,
        repeat_delay = 300,
        repeat_rate = 50,
        touchpad = {
          natural_scroll = true,
        },
      },
    })

    hl.bind(main_mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
    hl.bind(main_mod .. " + Q", hl.dsp.window.close())
    hl.bind(main_mod .. " + SPACE", hl.dsp.exec_cmd("${pkgs.fuzzel}/bin/fuzzel"))
    hl.bind(main_mod .. " + F", hl.dsp.exec_cmd("${pkgs.nautilus}/bin/nautilus"))
    hl.bind(main_mod .. " + B", hl.dsp.exec_cmd("${config.programs.firefox.finalPackage}/bin/firefox"))
    hl.bind(main_mod .. " + C", hl.dsp.exec_cmd("${pkgs.vscodium}/bin/codium"))
    hl.bind(main_mod .. " + L", hl.dsp.exec_cmd("pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock"))
    hl.bind(main_mod .. " + left", snap_focused_window(0, 0, 0.5, 1))
    hl.bind(main_mod .. " + right", snap_focused_window(0.5, 0, 0.5, 1))
    hl.bind(main_mod .. " + up", snap_focused_window(0, 0, 1, 0.5))
    hl.bind(main_mod .. " + down", snap_focused_window(0, 0.5, 1, 0.5))
    hl.bind(main_mod .. " + SHIFT + S", hl.dsp.exec_cmd("${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy --type image/png"))
    hl.bind(main_mod .. " + V", hl.dsp.exec_cmd("${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"))
    hl.bind(main_mod .. " + SHIFT + V", hl.dsp.exec_cmd("${pkgs.cliphist}/bin/cliphist wipe"))

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
      format = "󰥔  {:%a %b %d  %H:%M}";
      tooltip-format = "{:%Y-%m-%d}\nClick to copy the current timestamp";
      on-click = "${pkgs.coreutils}/bin/date --iso-8601=seconds | ${pkgs.wl-clipboard}/bin/wl-copy";
    };

    network = {
      format-wifi = "󰖩  {signalStrength}%";
      format-ethernet = "󰈀";
      format-disconnected = "󰖪";
      tooltip-format-wifi = "{essid} ({signalStrength}%)\nClick to manage connections";
      tooltip-format-ethernet = "{ifname}\nClick to manage connections";
      tooltip-format-disconnected = "Disconnected\nClick to manage connections";
      on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
    };

    pulseaudio = {
      format = "{icon}  {volume}%";
      format-muted = "󰝟";
      format-icons = [ "" "" "" ];
      tooltip-format = "{desc}\nClick for audio controls; right-click to mute";
      on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
      on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    };

    backlight = {
      format = "{icon}  {percent}%";
      format-icons = [ "󰃞" "󰃟" "󰃠" ];
      tooltip-format = "Brightness: {percent}%\nLeft/right click to adjust";
      on-click = "${pkgs.brightnessctl}/bin/brightnessctl set 10%+";
      on-click-right = "${pkgs.brightnessctl}/bin/brightnessctl set 10%-";
      on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
      on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
    };

    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon}  {capacity}%";
      format-charging = "  {capacity}%";
      format-plugged = "  {capacity}%";
      format-icons = [ "" "" "" "" "" ];
      tooltip-format = "{time}\nClick to toggle balanced/power-saver mode";
      on-click = "${togglePowerProfile}";
    };

    tray.spacing = 8;
  };
  style = ''
    * {
      font-family: "JetBrainsMono Nerd Font", sans-serif;
      font-size: 13px;
    }

    window#waybar {
      background: #f5e4d8;
      color: #3a1911;
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

    #clock:hover,
    #network:hover,
    #pulseaudio:hover,
    #backlight:hover,
    #battery:hover {
      background: #f6e7dc;
      border-radius: 6px;
    }

    #workspaces button.active { color: #805f36; }
    #battery.warning { color: #7b5521; }
    #battery.critical { color: #562b00; }
    #pulseaudio.muted,
    #network.disconnected { color: #7f7974; }
  '';
};
}
