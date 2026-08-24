{ config, lib, pkgs, aiUsage, blixTheme, sessionSwitcher, theme, nightMode, ... }:

let
  isLaptop = config.blix.formFactor == "laptop";
  uint = value: { type = "uint"; inherit value; };

  barWidget = import ../scripts/xfce-bar-widget.nix {
    inherit pkgs nightMode;
    currentThemeDir = config.blix.currentThemeDir;
  };

  panelReload = pkgs.writeShellApplication {
    name = "blix-reload-xfce-panel";
    runtimeInputs = [ pkgs.coreutils pkgs.procps pkgs.xfce4-panel pkgs.xfconf ];
    text = ''
      ${blixTheme}/bin/blix-theme apply || true
      panel_pattern='(^|/)xfce4-panel( --disable-wm-check)?$'
      panel_css_migration_stamp="''${XDG_STATE_HOME:-$HOME/.local/state}/blix/xfce-panel-native-colors-v1"

      if pgrep --full "$panel_pattern" >/dev/null; then
        set_command() {
          xfconf-query \
            --channel xfce4-panel \
            --property "/plugins/plugin-$1/command" \
            --set "$2"
          # Refresh in place: restarting the panel can exhaust XFCE's session
          # restart limit, while a missing panel makes plugin-event wait forever.
          timeout 2s xfce4-panel \
            --plugin-event="genmon-$1:refresh:bool:true" || true
        }

        hide_label() {
          xfconf-query \
            --channel xfce4-panel \
            --property "/plugins/plugin-$1/use-label" \
            --set false
        }

        set_period() {
          xfconf-query \
            --channel xfce4-panel \
            --property "/plugins/plugin-$1/update-period" \
            --set "$2"
        }

        set_command 3 '${barWidget}/bin/blix-xfce-bar-widget night'
        hide_label 3
        set_period 3 1000
        set_command 4 '${barWidget}/bin/blix-xfce-bar-widget idle'
        hide_label 4
        set_period 4 1000
        set_command 7 '${barWidget}/bin/blix-xfce-bar-widget theme'
        hide_label 7
        set_period 7 5000
        set_command 8 '${aiUsage}/bin/ai-usage genmon'
        set_period 8 300000
        ${lib.optionalString isLaptop ''
          set_command 11 '${barWidget}/bin/blix-xfce-bar-widget brightness'
          hide_label 11
          set_period 11 1000
        ''}

        # GTK reads user CSS only when a process starts. Restart the panel once
        # to discard the old palette-specific rules; subsequent theme changes
        # use the live xfconf color properties set by blix-theme.
        if [ ! -e "$panel_css_migration_stamp" ]; then
          xfce4-panel --restart || true
        fi
      fi

      if [ ! -e "$panel_css_migration_stamp" ]; then
        mkdir -p "$(dirname "$panel_css_migration_stamp")"
        touch "$panel_css_migration_stamp"
      fi
    '';
  };

  panelPluginIds = [ 1 2 3 4 5 6 7 8 9 10 ]
    ++ lib.optionals isLaptop [ 11 12 ];

  panelSettings = {
    panels = [ 1 ];
    "panels/dark-mode" = false;
    "panels/panel-1/icon-size" = uint 18;
    "panels/panel-1/length" = uint 100;
    "panels/panel-1/plugin-ids" = panelPluginIds;
    "panels/panel-1/position" = "p=6;x=0;y=0";
    "panels/panel-1/position-locked" = true;
    "panels/panel-1/size" = uint 30;

    # Left: workspaces. The two expanding separators keep the controls and
    # clock centered while the status widgets remain right-aligned.
    "plugins/plugin-1" = "pager";
    "plugins/plugin-1/miniature-view" = true;
    "plugins/plugin-1/rows" = uint 1;
    "plugins/plugin-2" = "separator";
    "plugins/plugin-2/expand" = true;
    "plugins/plugin-2/style" = uint 0;

    # Center: GenMon hosts the Blix actions that have no native Xfce plugin,
    # while the clock remains Xfce's native clock plugin.
    "plugins/plugin-3" = "genmon";
    "plugins/plugin-3/command" = "${barWidget}/bin/blix-xfce-bar-widget night";
    "plugins/plugin-3/enable-single-row" = true;
    "plugins/plugin-3/update-period" = 1000;
    "plugins/plugin-3/use-label" = false;
    "plugins/plugin-4" = "genmon";
    "plugins/plugin-4/command" = "${barWidget}/bin/blix-xfce-bar-widget idle";
    "plugins/plugin-4/enable-single-row" = true;
    "plugins/plugin-4/update-period" = 1000;
    "plugins/plugin-4/use-label" = false;
    "plugins/plugin-5" = "clock";
    "plugins/plugin-5/digital-format" = "%a %b %d  %H:%M";
    "plugins/plugin-5/mode" = uint 2;
    "plugins/plugin-6" = "separator";
    "plugins/plugin-6/expand" = true;
    "plugins/plugin-6/style" = uint 0;

    # Right: GenMon hosts the Blix theme and AI actions. NetworkManager uses
    # Xfce's native status tray, audio uses its PulseAudio plugin, and laptop
    # builds add an explicit brightness control plus Xfce's battery indicator.
    "plugins/plugin-7" = "genmon";
    "plugins/plugin-7/command" = "${barWidget}/bin/blix-xfce-bar-widget theme";
    "plugins/plugin-7/enable-single-row" = true;
    "plugins/plugin-7/update-period" = 5000;
    "plugins/plugin-7/use-label" = false;
    "plugins/plugin-8" = "genmon";
    "plugins/plugin-8/command" = "${aiUsage}/bin/ai-usage genmon";
    "plugins/plugin-8/enable-single-row" = true;
    "plugins/plugin-8/update-period" = 300000;
    "plugins/plugin-8/use-label" = false;
    "plugins/plugin-9" = "systray";
    "plugins/plugin-9/square-icons" = true;
    "plugins/plugin-10" = "pulseaudio";
  } // lib.optionalAttrs isLaptop {
    "plugins/plugin-11" = "genmon";
    "plugins/plugin-11/command" = "${barWidget}/bin/blix-xfce-bar-widget brightness";
    "plugins/plugin-11/enable-single-row" = true;
    "plugins/plugin-11/update-period" = 1000;
    "plugins/plugin-11/use-label" = false;
    "plugins/plugin-12" = "power-manager-plugin";
  };

  workspaceBindings = lib.listToAttrs (
    lib.concatMap (workspace: [
      {
        name = "xfwm4/custom/<Super>${toString workspace}";
        value = "workspace_${toString workspace}_key";
      }
      {
        name = "xfwm4/custom/<Shift><Super>${toString workspace}";
        value = "move_window_workspace_${toString workspace}_key";
      }
    ]) (lib.range 1 5)
  );
in
{
  # Home Manager's xfconf module updates declared properties but deliberately
  # preserves undeclared ones. The stock Xfce panel leaves a second panel and
  # overlapping plugin IDs behind, so reset this fully-owned channel before
  # loading the declarative Blix layout.
  home.activation.blixXfcePanelReset = lib.hm.dag.entryBefore [ "xfconfSettings" ] ''
    run ${pkgs.xfconf}/bin/xfconf-query \
      --channel xfce4-panel \
      --property / \
      --reset \
      --recursive || true
  '';

  # NixOS runs Home Manager activation outside the graphical session, so a
  # direct panel restart cannot reach its X display. Run it through the user
  # manager, which owns the session environment, after both the xfconf writes
  # and the generated unit are available.
  home.activation.blixXfcePanelReload = lib.hm.dag.entryAfter [
    "xfconfSettings"
    "reloadSystemd"
  ] ''
    run ${pkgs.systemd}/bin/systemctl --user start blix-xfce-panel-reload.service || true
  '';

  systemd.user.services.blix-xfce-panel-reload = {
    Unit.Description = "Apply the Blix XFCE panel layout and theme";
    Service = {
      Type = "oneshot";
      ExecStart = "${panelReload}/bin/blix-reload-xfce-panel";
    };
  };

  # These settings mirror Blix's Hyprland shortcuts. Home Manager writes them
  # through xfconf, avoiding hardware-specific XML copied from another host.
  xfconf.settings = {
    keyboards = {
      "Default/KeyRepeat/Delay" = 300;
      "Default/KeyRepeat/Rate" = 50;
    };

    xfce4-desktop = {
      "desktop-icons/file-icons/show-filesystem" = true;
      "desktop-icons/file-icons/show-home" = true;
      "desktop-icons/file-icons/show-removable" = false;
      "desktop-icons/file-icons/show-trash" = true;
      "desktop-icons/style" = 2;
    };

    xfce4-keyboard-shortcuts = {
      "commands/custom/<Alt><Super>space" = "${pkgs.xfdesktop}/bin/xfdesktop --menu";
      "commands/custom/<Shift><Super>s" = "${pkgs.xfce4-screenshooter}/bin/xfce4-screenshooter -r -c";
      "commands/custom/<Super>Return" = "${config.programs.alacritty.package}/bin/alacritty";
      "commands/custom/<Super>b" = "${config.programs.firefox.finalPackage}/bin/firefox";
      "commands/custom/<Super>c" = "${pkgs.vscodium}/bin/codium";
      "commands/custom/<Super>f" = "${pkgs.nautilus}/bin/nautilus";
      "commands/custom/<Super>l" = "${sessionSwitcher}/bin/blix-switch-session";
      "commands/custom/<Super>space" = "${pkgs.xfce4-appfinder}/bin/xfce4-appfinder";
      "commands/custom/override" = true;

      "xfwm4/custom/<Shift><Super>f" = "maximize_window_key";
      "xfwm4/custom/<Super>Down" = "tile_down_key";
      "xfwm4/custom/<Super>Left" = "tile_left_key";
      "xfwm4/custom/<Super>Right" = "tile_right_key";
      "xfwm4/custom/<Super>Tab" = "switch_window_key";
      "xfwm4/custom/<Super>Up" = "tile_up_key";
      "xfwm4/custom/<Super>q" = "close_window_key";
      "xfwm4/custom/override" = true;
    } // workspaceBindings;

    # modules/laptop.nix declares lid behavior for every desktop. Tell Xfce's
    # power manager not to take a second inhibitor or perform a second action.
    xfce4-power-manager."xfce4-power-manager/logind-handle-lid-switch" = true;

    xfce4-panel = panelSettings;

    xfwm4."general/workspace_count" = 5;

    xsettings = {
      "Gtk/CursorThemeName" = theme.cursor.name;
      "Gtk/CursorThemeSize" = theme.cursor.size;
    };
  };
}
