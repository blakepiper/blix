# Hyprland keeps upstream defaults except for OXWM-style splits and scrolling.
{ config, lib, pkgs, osConfig, ... }:
let
  terminal = lib.getExe config.programs.ghostty.package;
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
    </fontconfig>
  '';
  start = pkgs.writeShellApplication {
    name = "start-blix-hyprland";
    runtimeInputs = [ pkgs.dbus ];
    text = ''
      previous_fontconfig="''${FONTCONFIG_FILE:-/etc/fonts/fonts.conf}"
      export FONTCONFIG_FILE=${fonts}
      dbus-update-activation-environment --systemd FONTCONFIG_FILE
      restore_fonts() {
        export FONTCONFIG_FILE="$previous_fontconfig"
        dbus-update-activation-environment --systemd FONTCONFIG_FILE
      }
      trap restore_fonts EXIT
      ${osConfig.programs.hyprland.package}/bin/start-hyprland "$@"
    '';
  };
in
{
  home.packages = with pkgs; [ wofi hyprlock screenshot start ];
  xdg.configFile."hypr/fontconfig.conf".source = fonts;
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- New windows split toward the right or bottom, as in OXWM's dwindle layout.
    hl.config({
      general = { layout = "dwindle" },
      dwindle = { force_split = 2 },
      input = {
        natural_scroll = true,
        touchpad = { natural_scroll = true },
      },
    })

    -- Familiar OXWM shortcuts.
    local exec = hl.dsp.exec_cmd
    hl.bind("SUPER + Return", exec("${terminal}"))
    hl.bind("SUPER + Space", exec("${launcher}"))
    hl.bind("SUPER + D", exec("${launcher}"))
    hl.bind("SUPER + F", exec("${pkgs.thunar}/bin/thunar"))
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
    hl.bind("SUPER + L", exec("${pkgs.hyprlock}/bin/hyprlock"))
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
