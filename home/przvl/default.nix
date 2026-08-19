{ config, pkgs, ... }:

let
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
fastfetch
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
        font_color = "rgb(cdd6f4)";
        inner_color = "rgb(313244)";
        outer_color = "rgb(89b4fa)";
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

services.mako.enable = true;

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

    hl.config({
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

    #clock:hover,
    #network:hover,
    #pulseaudio:hover,
    #backlight:hover,
    #battery:hover {
      background: #313244;
      border-radius: 6px;
    }

    #battery.warning { color: #f9e2af; }
    #battery.critical { color: #f38ba8; }
    #pulseaudio.muted,
    #network.disconnected { color: #a6adc8; }
  '';
};
}
