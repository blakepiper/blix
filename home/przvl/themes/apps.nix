# Turns one palette into the per-application configuration files that make up a
# theme. Every file here is regenerated for each palette, so adding a theme
# means adding a palette and nothing else.
{ pkgs, lib, font, isLaptop, nightMode, aiUsage, blixTheme }:

palette:

let
  c = palette.colors;

  # Most tools want bare hex; a few want it with the leading '#'.
  bare = value: lib.removePrefix "#" value;
  rgba = value: alpha: "rgba(${bare value}${alpha})";

  dark = palette.polarity == "dark";
  gtkTheme = if dark then "Adwaita-dark" else "Adwaita";

  tomlFormat = pkgs.formats.toml { };

  hyprlockConf = lib.hm.generators.toHyprconf {
    attrs = {
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
          color = "rgb(${bare c.foreground})";
          font_size = 72;
          font_family = font;
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
          font_color = "rgb(${bare c.foreground})";
          inner_color = "rgba(${bare c.background}aa)";
          outer_color = "rgb(${bare c.border})";
          outline_thickness = 3;
          placeholder_text = "";
        }
      ];
    };
  };

  wayleSettings = {
    general = {
      font-sans = font;
      font-mono = font;
    };

    styling = {
      theme-provider = "wayle";
      scale = 0.85;
      rounding = "none";
      palette = {
        bg = c.background;
        surface = c.surface;
        elevated = c.elevated;
        fg = c.foreground;
        fg-muted = c.muted;
        primary = c.primary;
        red = c.red;
        yellow = c.yellow;
        green = c.green;
        blue = c.blue;
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
          right = [ "custom-theme" "custom-ai-usage" "network" "volume" ]
            ++ lib.optionals isLaptop [ "brightness" "battery" ];
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
          id = "theme";
          command = "${blixTheme}/bin/blix-theme status";
          interval-ms = 0;
          icon-name = "cm-theme-symbolic";
          label-show = false;
          tooltip-format = "{{ tooltip }}";
          left-click = "${blixTheme}/bin/blix-theme menu";
          on-action = "${blixTheme}/bin/blix-theme status";
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
        left-click = "${pkgs.wayle}/bin/wayle idle toggle --indefinite";
      };
      # An invisible, fixed-width separator creates a clear visual break
      # between the status controls and the clock.
      separator = {
        size = 32;
        color = c.background;
      };
      network.label-show = false;
      volume.label-show = false;
      hyprland-workspaces = {
        display-mode = "none";
        app-icons-show = true;
      };
    } // lib.optionalAttrs isLaptop {
      brightness.label-show = false;
      battery = {
        label-show = false;
        thresholds = [
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
in
{
  # Imported by ~/.config/alacritty/alacritty.toml.
  "alacritty.toml" = tomlFormat.generate "blix-alacritty-colors" {
    colors = {
      primary = {
        background = c.background;
        foreground = c.foreground;
      };
      normal = {
        black = c.black;
        red = c.red;
        green = c.green;
        yellow = c.yellow;
        blue = c.blue;
        magenta = c.magenta;
        cyan = c.cyan;
        white = c.white;
      };
      bright = {
        black = c.brightBlack;
        red = c.brightRed;
        green = c.brightGreen;
        yellow = c.brightYellow;
        blue = c.brightBlue;
        magenta = c.brightMagenta;
        cyan = c.brightCyan;
        white = c.brightWhite;
      };
      cursor = {
        text = c.background;
        cursor = c.foreground;
      };
    };
  };

  # Included by ~/.config/fuzzel/fuzzel.ini. The include has its own section
  # scope, so the [colors] header has to be repeated here.
  "fuzzel.ini" = pkgs.writeText "blix-fuzzel-colors" ''
    [colors]
    background=${bare c.background}ff
    text=${bare c.foreground}ff
    match=${bare c.primary}ff
    selection=${bare c.primary}ff
    selection-text=${bare c.background}ff
    selection-match=${bare c.background}ff
    border=${bare c.border}ff
  '';

  # Imported by ~/.config/gtk-{3,4}.0/gtk.css.
  "gtk.css" = pkgs.writeText "blix-gtk-css" ''
    @define-color theme_bg_color ${c.background};
    @define-color theme_fg_color ${c.foreground};
    @define-color theme_selected_bg_color ${c.primary};
    @define-color theme_selected_fg_color ${c.background};
    @define-color window_bg_color ${c.background};
    @define-color window_fg_color ${c.foreground};
    @define-color accent_bg_color ${c.primary};
    @define-color accent_fg_color ${c.background};
    @define-color borders alpha(${c.foreground}, 0.15);
    selection { background-color: ${c.primary}; color: ${c.background}; }

    .xfce4-panel.background {
      background-color: ${c.background};
      color: ${c.foreground};
    }
    .xfce4-panel button {
      background-color: transparent;
      background-image: none;
      border-color: transparent;
      border-radius: 0;
      box-shadow: none;
      color: ${c.foreground};
    }
    .xfce4-panel button:hover,
    .xfce4-panel button:checked {
      background-color: ${c.elevated};
      color: ${c.foreground};
    }
  '';

  "btop.theme" = pkgs.writeText "blix-btop-theme" ''
    theme[main_bg]="${c.background}"
    theme[main_fg]="${c.foreground}"
    theme[title]="${c.primary}"
    theme[hi_fg]="${c.accent}"
    theme[selected_bg]="${c.elevated}"
    theme[selected_fg]="${c.foreground}"
    theme[inactive_fg]="${c.muted}"
    theme[graph_text]="${c.foreground}"
    theme[meter_bg]="${c.surface}"
    theme[proc_misc]="${c.accent}"
    theme[cpu_box]="${c.elevated}"
    theme[mem_box]="${c.elevated}"
    theme[net_box]="${c.elevated}"
    theme[proc_box]="${c.elevated}"
    theme[div_line]="${c.elevated}"
    theme[temp_start]="${c.blue}"
    theme[temp_mid]="${c.magenta}"
    theme[temp_end]="${c.red}"
    theme[cpu_start]="${c.green}"
    theme[cpu_mid]="${c.yellow}"
    theme[cpu_end]="${c.red}"
    theme[free_start]="${c.blue}"
    theme[free_mid]="${c.cyan}"
    theme[free_end]="${c.green}"
    theme[cached_start]="${c.cyan}"
    theme[cached_mid]="${c.blue}"
    theme[cached_end]="${c.magenta}"
    theme[available_start]="${c.yellow}"
    theme[available_mid]="${c.brightYellow}"
    theme[available_end]="${c.red}"
    theme[used_start]="${c.green}"
    theme[used_mid]="${c.yellow}"
    theme[used_end]="${c.red}"
    theme[download_start]="${c.blue}"
    theme[download_mid]="${c.cyan}"
    theme[download_end]="${c.magenta}"
    theme[upload_start]="${c.green}"
    theme[upload_mid]="${c.yellow}"
    theme[upload_end]="${c.red}"
  '';

  # Read by Neovim and handed to mini.base16, which derives every highlight
  # group from these sixteen colors.
  "base16.lua" = pkgs.writeText "blix-base16-lua" ''
    return {
      base00 = "${c.background}",
      base01 = "${c.surface}",
      base02 = "${c.elevated}",
      base03 = "${c.muted}",
      base04 = "${c.brightBlack}",
      base05 = "${c.foreground}",
      base06 = "${c.foreground}",
      base07 = "${c.white}",
      base08 = "${c.red}",
      base09 = "${c.brightYellow}",
      base0A = "${c.yellow}",
      base0B = "${c.green}",
      base0C = "${c.cyan}",
      base0D = "${c.blue}",
      base0E = "${c.magenta}",
      base0F = "${c.brightRed}",
    }
  '';

  # Symlinked in as the Firefox profile's user.js, which Firefox re-reads on
  # every start. Firefox derives its own light/dark from GTK, which does not
  # follow a runtime switch, so the answer is stated outright instead.
  "firefox.js" = pkgs.writeText "blix-firefox-js" ''
    user_pref("ui.systemUsesDarkTheme", ${if dark then "1" else "0"});
    // 2 = follow the system setting above, for both chrome and page content.
    user_pref("browser.theme.toolbar-theme", 2);
    user_pref("browser.theme.content-theme", 2);
  '';

  "hyprlock.conf" = pkgs.writeText "blix-hyprlock-conf" hyprlockConf;

  "wayle.toml" = tomlFormat.generate "blix-wayle-config" wayleSettings;

  # Fed to `hyprctl eval`. Hyprland's Lua parser rejects `hyprctl keyword`, and
  # wants gradients as a table rather than the hyprlang gradient string.
  "hyprland.lua" = pkgs.writeText "blix-hyprland-lua" ''
    hl.config({
      general = {
        ["col.active_border"] = {
          colors = { "${rgba c.primary "ee"}", "${rgba c.accent "ee"}" },
          angle = 45,
        },
        ["col.inactive_border"] = "${rgba c.elevated "aa"}",
      },
      decoration = {
        shadow = { color = "${rgba c.background "cc"}" },
      },
    })
  '';

  # Read by hyprpaper at session start. Switching themes also pushes the new
  # wallpaper over hyprpaper's IPC so it changes without a restart.
  "hyprpaper.conf" = pkgs.writeText "blix-hyprpaper-conf" (
    lib.hm.generators.toHyprconf {
      attrs = {
        splash = false;
        wallpaper = [
          {
            monitor = "";
            path = "${palette.wallpaper}";
            fit_mode = "cover";
          }
        ];
      };
      # hyprpaper requires `monitor` to be the first key of a wallpaper block;
      # without this the generator sorts it after fit_mode and hyprpaper exits.
      importantPrefixes = [ "$" "monitor" ];
    }
  );

  # Sourced by blix-theme for the parts that are applied with a command rather
  # than read from a file.
  "meta.sh" = pkgs.writeText "blix-theme-meta" ''
    LABEL=${lib.escapeShellArg palette.label}
    POLARITY=${lib.escapeShellArg palette.polarity}
    GTK_THEME=${lib.escapeShellArg gtkTheme}
    COLOR_SCHEME=${lib.escapeShellArg (if dark then "prefer-dark" else "prefer-light")}
    WALLPAPER=${lib.escapeShellArg "${palette.wallpaper}"}
  '';
}
