# Separate XFCE login from the OXWM ~/.xinitrc and Blix session services.
{ config, lib, osConfig, pkgs, blixSettings, scripts, ... }:

let
  blixScript = name: lib.getExe (lib.findFirst
    (package: lib.getName package == name)
    (throw "Missing Blix script: ${name}") scripts);
  commandShortcuts = [
    { key = "<Super>space"; value = "${pkgs.dmenu}/bin/dmenu_run"; }
    { key = "<Super>d"; value = "${pkgs.dmenu}/bin/dmenu_run"; }
    { key = "<Super>Return"; value = config.home.sessionVariables.TERMINAL; }
    { key = "<Super>f"; value = "${pkgs.xfe}/bin/xfe"; }
    { key = "<Super>b"; value = lib.getExe config.programs.firefox.finalPackage; }
    { key = "<Super>s"; value = "${blixSettings}/bin/blix-settings"; }
    { key = "<Super><Shift>s"; value = blixScript "screenshot-region"; }
    { key = "Print"; value = "${blixScript "screenshot-region"} --full"; }
    { key = "<Alt>Print"; value = "${blixScript "screenshot-region"} --window"; }
    { key = "<Super>v"; value = blixScript "clipboard-history"; }
    { key = "<Super>l"; value = "${pkgs.xfce4-session}/bin/xflock4"; }
    { key = "<Super><Shift>l"; value = "${pkgs.xfce4-session}/bin/xfce4-session-logout --suspend"; }
    { key = "XF86Sleep"; value = "${pkgs.xfce4-session}/bin/xfce4-session-logout --suspend"; }
    { key = "<Super><Shift>space"; value = "${pkgs.xfce4-session}/bin/xfce4-session-logout"; }
    { key = "<Super><Shift>q"; value = "${pkgs.xfce4-session}/bin/xfce4-session-logout"; }
    { key = "XF86AudioPlay"; value = "${pkgs.playerctl}/bin/playerctl play-pause"; }
    { key = "XF86AudioNext"; value = "${pkgs.playerctl}/bin/playerctl next"; }
    { key = "XF86AudioPrev"; value = "${pkgs.playerctl}/bin/playerctl previous"; }
  ] ++ lib.optional (osConfig.programs.steam.enable or false) {
    key = "<Super>g";
    value = "${osConfig.programs.steam.package}/bin/steam";
  };
  windowShortcuts = [
    { key = "<Super>q"; value = "close_window_key"; }
    { key = "<Super><Shift>f"; value = "maximize_window_key"; }
    { key = "<Super>m"; value = "maximize_window_key"; }
    { key = "<Super>Tab"; value = "left_workspace_key"; }
    { key = "<Super>Left"; value = "cycle_reverse_windows_key"; }
    { key = "<Super>Up"; value = "cycle_reverse_windows_key"; }
    { key = "<Super>Right"; value = "cycle_windows_key"; }
    { key = "<Super>Down"; value = "cycle_windows_key"; }
    { key = "<Super><Shift>Left"; value = "tile_left_key"; }
    { key = "<Super><Shift>Up"; value = "tile_up_key"; }
    { key = "<Super><Shift>Right"; value = "tile_right_key"; }
    { key = "<Super><Shift>Down"; value = "tile_down_key"; }
  ] ++ lib.concatMap (number: [
    { key = "<Super>${toString number}"; value = "workspace_${toString number}_key"; }
    { key = "<Super><Shift>${toString number}"; value = "move_window_workspace_${toString number}_key"; }
  ]) (lib.range 1 4);
  shortcutLines = group: bindings: lib.concatMapStringsSep "\n" ({ key, value }: ''
    xfconf-query -c xfce4-keyboard-shortcuts \
      -p ${lib.escapeShellArg "/${group}/custom/${key}"} \
      -n -t string -s ${lib.escapeShellArg value}
  '') bindings;
  configure = pkgs.writeShellApplication {
    name = "blix-xfce-configure";
    runtimeInputs = [ pkgs.xfconf ];
    text = ''
      xfconf-query -c xfwm4 -p /general/workspace_count -n -t int -s 4
      xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/override -n -t bool -s true
      xfconf-query -c xfce4-keyboard-shortcuts -p /xfwm4/custom/override -n -t bool -s true
      ${shortcutLines "commands" commandShortcuts}
      ${shortcutLines "xfwm4" windowShortcuts}
      for number in 5 6 7 8 9; do
        xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>$number" -r 2>/dev/null || true
        xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super><Shift>$number" -r 2>/dev/null || true
      done
    '' + lib.optionalString (config.blix.xfce.displayScale != null) ''
      while IFS= read -r property; do
        if [[ $property == /Default/*/Scale ]]; then
          xfconf-query -c displays -p "$property" -s ${toString config.blix.xfce.displayScale}
        fi
      done < <(xfconf-query -c displays -l)
    '' + lib.optionalString (config.blix.xfce.windowScalingFactor != null) ''
      xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -n -t int \
        -s ${toString config.blix.xfce.windowScalingFactor}
      xfconf-query -c xfwm4 -p /general/theme -n -t string -s Default-xhdpi
      xfconf-query -c xfwm4 -p /general/title_font -n -t string \
        -s ${lib.escapeShellArg "Sans Bold ${toString (6 * config.blix.xfce.windowScalingFactor)}"}
    '';
  };
  refreshWorkspaceShortcuts = pkgs.writeShellApplication {
    name = "blix-xfce-refresh-workspace-shortcuts";
    runtimeInputs = [ pkgs.xfconf ];
    text = ''
      # xfwm4 did not grab every saved workspace binding at startup.
      for number in 1 2 3 4; do
        switch="/xfwm4/custom/<Super>$number"
        move="/xfwm4/custom/<Super><Shift>$number"
        xfconf-query -c xfce4-keyboard-shortcuts -p "$switch" -r 2>/dev/null || true
        xfconf-query -c xfce4-keyboard-shortcuts -p "$switch" \
          -n -t string -s "workspace_''${number}_key"
        xfconf-query -c xfce4-keyboard-shortcuts -p "$move" -r 2>/dev/null || true
        xfconf-query -c xfce4-keyboard-shortcuts -p "$move" \
          -n -t string -s "move_window_workspace_''${number}_key"
      done
    '';
  };
  start = pkgs.writeShellApplication {
    name = "startxfce";
    runtimeInputs = [ pkgs.systemd pkgs.util-linux pkgs.xinit ];
    text = ''
      if [[ -n ''${DISPLAY:-} || -n ''${WAYLAND_DISPLAY:-} || $(tty) != /dev/tty* ]]; then
        echo 'Run startxfce from a local text console after exiting your desktop.' >&2
        exit 1
      fi
      if systemctl --user is-active --quiet blix-session.target blix-wayland-session.target blix-xfce-session.target; then
        echo 'Exit the existing Blix desktop before starting XFCE.' >&2
        exit 1
      fi
      exec 9>"$XDG_RUNTIME_DIR/blix-xfce.lock"
      flock -n 9 || { echo 'XFCE is already running.' >&2; exit 1; }
      exec startx "$HOME/.xfce-xinitrc" -- :0
    '';
  };
in
{
  options.blix.xfce.windowScalingFactor = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
    description = "XFCE window scaling factor for this user.";
  };

  options.blix.xfce.displayScale = lib.mkOption {
    type = lib.types.nullOr lib.types.numbers.positive;
    default = null;
    description = "XFCE Default display profile scale for known outputs at login.";
  };

  config = {
    home.packages = [ start ];

    home.file.".xfce-xinitrc" = {
      executable = true;
      text = "#!${pkgs.bash}/bin/bash\n" + ''
        export XDG_CURRENT_DESKTOP=XFCE
        export XDG_SESSION_DESKTOP=xfce
        export XDG_SESSION_TYPE=x11
        ${configure}/bin/blix-xfce-configure || exit 1
        ${pkgs.systemd}/bin/systemctl --user import-environment \
          DISPLAY XAUTHORITY PATH XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
        ${pkgs.systemd}/bin/systemctl --user start blix-xfce-session.target || exit 1
        cleanup() {
          ${pkgs.systemd}/bin/systemctl --user stop blix-xfce-session.target || true
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
            DISPLAY= XAUTHORITY= DESKTOP_SESSION= XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP= XDG_SESSION_TYPE= || true
          ${pkgs.systemd}/bin/systemctl --user unset-environment \
            DISPLAY XAUTHORITY DESKTOP_SESSION XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE || true
        }
        trap cleanup EXIT
        ${pkgs.bash}/bin/bash ${pkgs.xfce4-session.xinitrc}
      '';
    };

    xdg.configFile."autostart/blix-xfce-refresh-workspace-shortcuts.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Blix XFCE workspace shortcut
      Exec=${refreshWorkspaceShortcuts}/bin/blix-xfce-refresh-workspace-shortcuts
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-Phase=Applications
    '';

    systemd.user.targets.blix-xfce-session.Unit.Description = "Blix XFCE session";
    systemd.user.targets.blix-xfce-session.Unit.Wants = [ "blix-clipboard.service" ];
    systemd.user.services.blix-clipboard.Unit.PartOf = [ "blix-xfce-session.target" ];
  };
}
