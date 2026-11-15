# Hyprland adds Blix opacity to OXWM-style splits, scrolling and bindings.
{ config, lib, pkgs, osConfig, blixSettings, ... }:
let
  primaryOutput = config.blix.display.primaryOutput or null;
  wallpaper = config.blix.display.wallpaper or null;
  retroTerminalSize = config.blix.hyprland.retroTerminalSize;
  terminalFonts = pkgs.writeText "hyprland-terminal-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${pkgs.terminus_font_ttf}/share/fonts/truetype</dir>
    </fontconfig>
  '';
  terminal = pkgs.writeShellApplication {
    name = "hyprland-ghostty";
    text = ''
      # Tamsyn has only small bitmap strikes; use a scalable terminal font.
      # Keep this instance separate from terminals started with session fonts.
      export FONTCONFIG_FILE=${if retroTerminalSize == null then "/etc/fonts/fonts.conf" else terminalFonts}
      exec ${lib.getExe config.programs.ghostty.package} \
        --gtk-single-instance=false --quit-after-last-window-closed=true \
        ${lib.optionalString (retroTerminalSize != null) ''--font-family="Terminus (TTF)" --font-style=Bold --font-size=${toString retroTerminalSize}''} "$@"
    '';
  };
  launcher = "${pkgs.wofi}/bin/wofi --show drun";
  screenshot = pkgs.writeShellApplication {
    name = "hyprland-screenshot";
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard pkgs.coreutils ];
    text = ''
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      file="$directory/$(date +%Y-%m-%d_%H-%M-%S-%N).png"
      if [[ ''${1:-} == --full ]]; then
        grim "$file"
      else
        geometry=$(slurp) || exit 0
        grim -g "$geometry" "$file"
      fi
      wl-copy --type image/png < "$file"
    '';
  };
  barStatus = pkgs.writeShellApplication {
    name = "hyprland-bar-status";
    text = builtins.readFile ../config/quickshell/status.sh;
  };
  barQml = pkgs.writeText "blix-hyprland-bar.qml" (builtins.replaceStrings
    [ "@status-command@" "@power-mode-command@" "@brightness-command@" "@has-battery@" "@has-backlight@" "@has-power-profiles@" ]
    [ "${barStatus}/bin/hyprland-bar-status" "${blixSettings}/bin/blix-settings-apply" "${pkgs.brightnessctl}/bin/brightnessctl" (lib.boolToString config.blix.hardware.hasBattery) (lib.boolToString config.blix.hardware.hasBacklight) (lib.boolToString config.blix.hardware.hasPowerProfiles) ]
    (builtins.readFile ../config/quickshell/shell.qml));
  bar = pkgs.writeShellApplication {
    name = "blix-hyprland-bar";
    text = ''
      export FONTCONFIG_FILE=${terminalFonts}
      exec ${pkgs.quickshell}/bin/quickshell --path ${barQml}
    '';
  };
  hypridleConfig = pkgs.writeText "blix-hypridle.conf" ''
    general {
      lock_cmd = ${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock --grace 0 --immediate-render --no-fade-in
      before_sleep_cmd = ${pkgs.systemd}/bin/loginctl lock-session
      inhibit_sleep = 3
    }
  '';
  sessionStart = pkgs.writeShellApplication {
    name = "blix-hyprland-session-start";
    runtimeInputs = [ pkgs.dbus pkgs.systemd ];
    text = ''
      dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE BLIX_HYPRLAND_SESSION
      systemctl --user start --no-block blix-hyprsunset.service blix-hypridle.service
      ${lib.optionalString (wallpaper != null) "systemctl --user start --no-block blix-hyprland-wallpaper.service"}
    '';
  };
  controlMenu = pkgs.writeShellApplication {
    name = "hyprland-control-menu";
    runtimeInputs = [ pkgs.wofi pkgs.systemd pkgs.coreutils osConfig.programs.hyprland.package ];
    text = ''
      confirm() {
        local answer
        answer=$(printf 'No\nYes\n' | wofi --dmenu --no-custom-entry --prompt "$1") || return 1
        [[ $answer == Yes ]]
      }

      choice=$(printf 'Lock\nSuspend\nReboot\nLog Out\nMonitors Off\nPower Off\n' |
        wofi --dmenu --no-custom-entry --prompt Control) || exit 0
      case $choice in
        Lock) loginctl lock-session ;;
        Suspend) systemctl suspend ;;
        Reboot) if confirm 'Reboot?'; then systemctl reboot; fi ;;
        'Log Out') if confirm 'Log out? Unsaved work may be lost.'; then hyprctl dispatch exit; fi ;;
        'Monitors Off') sleep 0.2; hyprctl dispatch dpms off ;;
        'Power Off') if confirm 'Power off?'; then systemctl poweroff; fi ;;
      esac
    '';
  };
  fonts = pkgs.writeText "hyprland-tamsyn-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${pkgs.tamsyn}/share/fonts/misc</dir>
      <match target="pattern">
        <edit name="family" mode="assign_replace" binding="strong"><string>Tamsyn</string></edit>
        <edit name="weight" mode="assign"><const>bold</const></edit>
      </match>
      <match target="pattern">
        <test name="size" compare="less"><double>15</double></test>
        <edit name="size" mode="assign"><double>15</double></edit>
      </match>
      <match target="font">
        <test name="family" qual="any"><string>Tamsyn</string></test>
        <edit name="antialias" mode="assign"><bool>false</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintfull</const></edit>
        <edit name="embeddedbitmap" mode="assign"><bool>true</bool></edit>
      </match>
    </fontconfig>
  '';
  start = pkgs.writeShellApplication {
    name = "start-blix-hyprland";
    runtimeInputs = [ pkgs.dbus pkgs.systemd ];
    text = ''
      previous_fontconfig="''${FONTCONFIG_FILE:-/etc/fonts/fonts.conf}"
      previous_hyprland_session="''${BLIX_HYPRLAND_SESSION:-}"
      export FONTCONFIG_FILE=${fonts}
      export BLIX_HYPRLAND_SESSION=1
      dbus-update-activation-environment --systemd FONTCONFIG_FILE BLIX_HYPRLAND_SESSION
      restore_fonts() {
        export FONTCONFIG_FILE="$previous_fontconfig"
        if [[ -n $previous_hyprland_session ]]; then
          export BLIX_HYPRLAND_SESSION="$previous_hyprland_session"
          dbus-update-activation-environment --systemd FONTCONFIG_FILE BLIX_HYPRLAND_SESSION
        else
          unset BLIX_HYPRLAND_SESSION
          dbus-update-activation-environment --systemd FONTCONFIG_FILE BLIX_HYPRLAND_SESSION=
          systemctl --user unset-environment BLIX_HYPRLAND_SESSION
        fi
        dbus-update-activation-environment --systemd HYPRLAND_INSTANCE_SIGNATURE=
        systemctl --user unset-environment HYPRLAND_INSTANCE_SIGNATURE
      }
      restore_session() {
        systemctl --user stop blix-hypridle.service >/dev/null 2>&1 || true
        ${lib.optionalString (wallpaper != null) "systemctl --user stop blix-hyprland-wallpaper.service >/dev/null 2>&1 || true"}
        systemctl --user stop blix-hyprsunset.service >/dev/null 2>&1 || true
        restore_fonts
      }
      trap restore_session EXIT
      ${osConfig.programs.hyprland.package}/bin/start-hyprland "$@"
    '';
  };
in
{
  options.blix.hyprland.retroTerminalSize = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
    description = "Terminus TTF Bold size for the Hyprland terminal, or null for Ghostty defaults.";
  };

  config.systemd.user.services = {
    blix-hypridle = {
      Unit.Description = "Lock Hyprland before system suspend";
      Service = {
        Type = "exec";
        ExecStart = "${pkgs.hypridle}/bin/hypridle -c ${hypridleConfig}";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  } // lib.optionalAttrs (wallpaper != null) {
    blix-hyprland-wallpaper = {
      Unit = {
        Description = "Blix Hyprland wallpaper";
        ConditionPathExists = wallpaper;
      };
      Service = {
        Type = "exec";
        ExecStart = "${pkgs.swaybg}/bin/swaybg -m fill -i ${wallpaper}";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };

  config.home.packages = with pkgs; [ wofi hyprlock screenshot controlMenu bar sessionStart start ];
  config.xdg.configFile."hypr/fontconfig.conf".source = fonts;
  config.xdg.configFile."hypr/hyprland.lua".text = ''
    -- New windows split toward the right or bottom, as in OXWM's dwindle layout.
    hl.config({
      general = { layout = "dwindle", gaps_out = 10 },
      decoration = {
        active_opacity = 0.85,
        inactive_opacity = 0.80,
        rounding = 10,
      },
      dwindle = { force_split = 2 },
      input = {
        natural_scroll = true,
        touchpad = { natural_scroll = true },
      },
    })

    hl.layer_rule({
      name = "blix-control-popup-glass",
      match = { namespace = "^blix-control-popup$" },
      blur = true,
      -- Exclude fully transparent pixels so blur follows the rounded card mask.
      ignore_alpha = 0.0,
    })
    hl.layer_rule({
      name = "blix-calendar-popup-glass",
      match = { namespace = "^blix-calendar-popup$" },
      blur = true,
      ignore_alpha = 0.0,
    })

    ${lib.optionalString (primaryOutput != null) ''
      -- Mirror newly connected outputs to the host's built-in primary panel.
      hl.monitor({ output = "${primaryOutput}", mode = "preferred", position = "auto", scale = "auto" })
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "${primaryOutput}" })
    ''}

    hl.on("hyprland.start", function()
      hl.exec_cmd("${sessionStart}/bin/blix-hyprland-session-start")
      hl.exec_cmd("${blixSettings}/bin/blix-settings-apply apply-transparency")
      hl.exec_cmd("${bar}/bin/blix-hyprland-bar")
    end)

    -- Preserve the X11 compositor exceptions for videos and Steam games.
    hl.window_rule({
      name = "opaque-firefox-video",
      match = { class = "^firefox$", title = "^\\[blix-video\\] " },
      opacity = "1.0 override 1.0 override 1.0 override",
    })
    hl.window_rule({
      name = "opaque-steam-games",
      match = { class = "^steam_app_.*$" },
      opacity = "1.0 override 1.0 override 1.0 override",
    })

    -- Familiar OXWM shortcuts.
    local exec = hl.dsp.exec_cmd
    hl.bind("SUPER + Return", exec("${terminal}/bin/hyprland-ghostty"))
    hl.bind("SUPER + Space", exec("${launcher}"))
    hl.bind("SUPER + SHIFT + Space", exec("${controlMenu}/bin/hyprland-control-menu"))
    hl.bind("SUPER + D", exec("${launcher}"))
    hl.bind("SUPER + F", exec("${pkgs.thunar}/bin/thunar"))
    hl.bind("SUPER + S", exec("${blixSettings}/bin/blix-settings"))
    hl.bind("SUPER + B", exec("${lib.getExe config.programs.firefox.package}"))
    hl.bind("SUPER + SHIFT + B", exec("${lib.getExe config.programs.firefox.package} --private-window"))
    hl.bind("SUPER + Q", hl.dsp.window.close())
    hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())
    hl.bind("SUPER + P", hl.dsp.window.float())
    hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen())
    hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "e-1" }))
    for _, pair in ipairs({ { "Left", "left" }, { "Right", "right" },
                            { "Up", "up" }, { "Down", "down" } }) do
      hl.bind("SUPER + " .. pair[1], hl.dsp.focus({ direction = pair[2] }))
      hl.bind("SUPER + SHIFT + " .. pair[1], hl.dsp.window.swap({ direction = pair[2] }))
    end
    for _, pair in ipairs({ { "Left", "-1" }, { "Right", "+1" } }) do
      hl.bind("SUPER + CTRL + " .. pair[1], hl.dsp.focus({ monitor = pair[2] }))
      hl.bind("SUPER + CTRL + SHIFT + " .. pair[1], hl.dsp.window.move({ monitor = pair[2] }))
    end
    for i = 1, 9 do
      hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
      hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
    end
    hl.bind("SUPER + L", exec("${pkgs.systemd}/bin/loginctl lock-session"))
    hl.bind("SUPER + SHIFT + S", exec("${screenshot}/bin/hyprland-screenshot"))
    hl.bind("Print", exec("${screenshot}/bin/hyprland-screenshot --full"))
    hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

    hl.bind("XF86AudioRaiseVolume", exec("${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
    hl.bind("XF86AudioLowerVolume", exec("${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
    hl.bind("XF86AudioMute", exec("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioMicMute", exec("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
    hl.bind("XF86AudioPlay", exec("${pkgs.playerctl}/bin/playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioNext", exec("${pkgs.playerctl}/bin/playerctl next"), { locked = true })
    hl.bind("XF86AudioPrev", exec("${pkgs.playerctl}/bin/playerctl previous"), { locked = true })
    ${lib.optionalString config.blix.hardware.hasBacklight ''
      hl.bind("XF86MonBrightnessUp", exec("${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set 5%+"), { repeating = true, locked = true })
      hl.bind("XF86MonBrightnessDown", exec("${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set 5%-"), { repeating = true, locked = true })
    ''}
    ${lib.optionalString osConfig.programs.steam.enable ''
      hl.bind("SUPER + G", exec("${osConfig.programs.steam.package}/bin/steam"))
    ''}
  '';
}
