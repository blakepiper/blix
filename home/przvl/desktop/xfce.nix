{ config, lib, pkgs, sessionSwitcher, theme, ... }:

let
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

    xfwm4."general/workspace_count" = 5;

    xsettings = {
      "Gtk/CursorThemeName" = theme.cursor.name;
      "Gtk/CursorThemeSize" = theme.cursor.size;
    };
  };
}
