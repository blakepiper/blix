{ config, lib, pkgs, theme, ... }:

let
  # Rendered at the base indentation of the extraConfig block below.
  renderMonitor = m: ''
    hl.monitor({
      output = "${m.output}",
      mode = "${m.mode}",
      position = "${m.position}",
      scale = ${builtins.toJSON m.scale},
    })
  '';
  monitors = lib.concatMapStrings renderMonitor config.blix.monitors;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    settings = {
      env = [
        { _args = [ "XCURSOR_THEME" theme.cursor.name ]; }
        { _args = [ "XCURSOR_SIZE" (toString theme.cursor.size) ]; }
      ];
    };
    extraConfig = ''
      local main_mod = "SUPER"
      local terminal = "alacritty"

      ${monitors}
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

      for workspace = 1, 5 do
        hl.bind(main_mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
        hl.bind(
          main_mod .. " + SHIFT + " .. workspace,
          hl.dsp.window.move({ workspace = workspace })
        )
      end
    '';
  };
}
