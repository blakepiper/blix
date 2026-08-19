{ config, pkgs, ... }:

let
  lakesAndLightWallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/mattbbia/lakes-and-light/1c14ea7b3fbb0bc8bd7097c74261e65affdc712b/backgrounds/lake-albano-1790-1792.jpg";
    hash = "sha256-iOBqjWHqqPaTNbFfKryBRF+P3A0MLSjqlYrH6sr5iqk=";
  };

  # Keep the provider adapters in sync with the original implementation.  The
  # small wrapper below adapts their JSON for Wayle and its fuzzel details view.
  modelUsageSource = pkgs.fetchFromGitHub {
    owner = "blakepiper";
    repo = "blarchy";
    rev = "1badd3452d4e94f23b122970ae1f41bb79c68f85";
    hash = "sha256-nDTvfDm4PmZj8k4v8dsjy4Ru8LiEJa2nGLxas5CmBHo=";
  };

  aiUsage = pkgs.writers.writePython3Bin "ai-usage" {
    flakeIgnore = [ "E302" "E305" "E306" "E501" ];
  } ''
    import json
    import subprocess
    import sys
    import urllib.request
    from datetime import datetime, timezone
    from pathlib import Path

    scanners = {
        "Claude Code": ["${pkgs.python3}/bin/python3", "${modelUsageSource}/shell/plugins/model-usage/scripts/claude_usage_scanner.py"],
        "Codex": ["${pkgs.python3}/bin/python3", "${modelUsageSource}/shell/plugins/model-usage/scripts/codex_usage_scanner.py"],
        "OpenCode Go": ["${pkgs.python3}/bin/python3", "${modelUsageSource}/shell/plugins/model-usage/scripts/opencode_go_usage_scanner.py"],
    }

    def run_scanner(name):
        try:
            result = subprocess.run(scanners[name], text=True, capture_output=True, timeout=25, check=True)
            return json.loads(result.stdout)
        except Exception as error:
            return {"usageStatusText": f"{name} unavailable: {error}", "rateLimitPercent": -1}

    def read_claude_limits():
        credentials = Path.home() / ".claude/.credentials.json"
        try:
            oauth = json.loads(credentials.read_text())["claudeAiOauth"]
            token = oauth["accessToken"]
            request = urllib.request.Request(
                "https://api.anthropic.com/api/oauth/usage",
                headers={
                    "Authorization": f"Bearer {token}",
                    "anthropic-beta": "oauth-2025-04-20",
                    "Accept": "application/json",
                },
            )
            with urllib.request.urlopen(request, timeout=10) as response:
                payload = json.load(response)
            weekly = payload.get("seven_day_oauth_apps") or payload.get("seven_day") or {}
            session = payload.get("five_hour") or {}
            def utilization(bucket):
                value = float(bucket.get("utilization", -1))
                return value / 100 if value > 1 else value
            return {
                "tierLabel": oauth.get("subscriptionType") or oauth.get("rateLimitTier") or "",
                "rateLimitPercent": utilization(session),
                "rateLimitLabel": "Session (5-hour)",
                "rateLimitResetAt": session.get("resets_at", ""),
                "secondaryRateLimitPercent": utilization(weekly),
                "secondaryRateLimitLabel": "Weekly (7-day)",
                "secondaryRateLimitResetAt": weekly.get("resets_at", ""),
            }
        except Exception as error:
            return {"usageStatusText": f"Claude limits unavailable: {error}", "rateLimitPercent": -1}

    def load_providers():
        claude = run_scanner("Claude Code")
        claude.update(read_claude_limits())
        return [("Claude Code", claude), ("Codex", run_scanner("Codex")), ("OpenCode Go", run_scanner("OpenCode Go"))]

    def percent(value):
        try:
            value = float(value)
            return value if value >= 0 else None
        except (TypeError, ValueError):
            return None

    def reset_text(value):
        if not value:
            return ""
        try:
            timestamp = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
            seconds = max(0, int((timestamp - datetime.now(timezone.utc)).total_seconds()))
            hours, seconds = divmod(seconds, 3600)
            minutes = seconds // 60
            return f" · resets in {hours}h {minutes}m" if hours else f" · resets in {minutes}m"
        except ValueError:
            return f" · resets {value}"

    def limit_rows(data):
        rows = []
        for prefix in ("rateLimit", "secondaryRateLimit", "tertiaryRateLimit"):
            used = percent(data.get(prefix + "Percent"))
            if used is None:
                continue
            label = data.get(prefix + "Label") or "Limit"
            rows.append(f"  {label}: {used:.0%} used · {1 - used:.0%} left" + reset_text(data.get(prefix + "ResetAt")))
        return rows

    def token_text(tokens):
        tokens = int(tokens or 0)
        return f"{tokens / 1000000:.1f}M" if tokens >= 1000000 else f"{tokens / 1000:.1f}K" if tokens >= 1000 else str(tokens)

    def details(providers):
        lines = []
        for name, data in providers:
            tier = data.get("tierLabel") or ""
            lines.append(name + (" · " + tier if tier else ""))
            rows = limit_rows(data)
            if rows:
                lines.extend(rows)
            else:
                lines.append("  " + (data.get("usageStatusText") or "No signed-in usage data"))
            lines.append(f"  Today: {token_text(data.get('todayTotalTokens'))} tokens · {data.get('todayPrompts', 0)} prompts")
            lines.append("")
        return "\n".join(lines).rstrip()

    def summary(providers):
        usage = [used for _, data in providers for used in (percent(data.get("rateLimitPercent")), percent(data.get("secondaryRateLimitPercent")), percent(data.get("tertiaryRateLimitPercent"))) if used is not None]
        text = f"AI {1 - max(usage):.0%} left" if usage else "AI —"
        return json.dumps({"text": text, "tooltip": details(providers), "percentage": int(max(usage, default=0) * 100)})

    providers = load_providers()
    if len(sys.argv) > 1 and sys.argv[1] == "details":
        print(details(providers))
    else:
        print(summary(providers))
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
claude-code
opencode
aiUsage
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
    label = [
      {
        monitor = "";
        text = "$TIME";
        color = "rgb(3a1911)";
        font_size = 72;
        font_family = "JetBrainsMono Nerd Font";
        position = "0, 100";
        halign = "center";
        valign = "center";
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
        placeholder_text = "";
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

services.hyprsunset = {
  enable = true;
  settings.profile = [
    {
      time = "00:00";
      identity = true;
    }
  ];
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
  package = pkgs.whitesur-cursors;
  name = "WhiteSur-cursors";
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
  settings = {
    env = [
    { _args = [ "XCURSOR_THEME" "WhiteSur-cursors" ]; }
    { _args = [ "XCURSOR_SIZE" "32" ]; }
    ];
  };
  extraConfig = ''
    local main_mod = "SUPER"
    local terminal = "alacritty"

    hl.monitor({
      output = "eDP-1",
      mode = "1920x1080@60.008",
      position = "0x0",
      scale = 1.25,
    })
    hl.monitor({
      output = "HDMI-A-2",
      mode = "3840x2160@30",
      position = "-2560x0",
      scale = 1.5,
    })

    local function snap_focused_window(x, y, width, height)
      return function()
        local window = hl.get_active_window()
        if not window or not window.monitor then return end

        local monitor = window.monitor
        local reserved = monitor.reserved
        local top = reserved[1] or 0
        local bottom = reserved[2] or 0
        local left = reserved[3] or 0
        local right = reserved[4] or 0
        -- Monitor dimensions are physical pixels, while window geometry uses
        -- logical coordinates.  Account for output scale and layer-shell
        -- reservations (such as the top bar) before splitting the work area.
        local work_x = monitor.x + left
        local work_y = monitor.y + top
        local work_width = monitor.width / monitor.scale - left - right
        local work_height = monitor.height / monitor.scale - top - bottom
        hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
        hl.dispatch(hl.dsp.window.resize({
          x = work_width * width,
          y = work_height * height,
          window = window,
        }))
        hl.dispatch(hl.dsp.window.move({
          x = work_x + work_width * x,
          y = work_y + work_height * y,
          window = window,
        }))
      end
    end

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
    hl.bind(main_mod .. " + SHIFT + F", hl.dsp.window.fullscreen())
    hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
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

services.wayle = {
  enable = true;
  settings = {
    general = {
      font-sans = "JetBrainsMono Nerd Font";
      font-mono = "JetBrainsMono Nerd Font";
    };

    styling = {
      theme-provider = "wayle";
      scale = 0.85;
      rounding = "none";
      palette = {
        bg = "#f5e4d8";
        surface = "#f6e7dc";
        elevated = "#ead6c7";
        fg = "#3a1911";
        fg-muted = "#7f7974";
        primary = "#805f36";
        red = "#562b00";
        yellow = "#7b5521";
        green = "#653e00";
        blue = "#805f36";
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
          center = [ "hyprsunset" "idle-inhibit" "clock" ];
          right = [ "custom-ai-usage" "network" "volume" "brightness" "battery" ];
        }
      ];
    };

    modules = {
      custom = [
        {
          id = "ai-usage";
          command = "${aiUsage}/bin/ai-usage";
          interval-ms = 300000;
          icon-name = "ld-sparkles";
          tooltip-format = "{{ tooltip }}";
          left-click = "${aiUsage}/bin/ai-usage details | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt='AI usage' --lines=14 --width=70";
        }
      ];
      clock.format = "%a %b %d  %H:%M";
      hyprsunset = {
        temperature = 3500;
        label-show = false;
      };
      idle-inhibit = {
        label-show = false;
        left-click = "wayle idle toggle --indefinite";
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
