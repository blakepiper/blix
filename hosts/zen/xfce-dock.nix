# Zen's existing second XFCE panel uses launcher plugin IDs 13–16.
{ pkgs, ... }:

let
  launcher = name: command: icon: ''
    [Desktop Entry]
    Type=Application
    Name=${name}
    Exec=${command}
    Icon=${icon}
    Terminal=false
    StartupNotify=true
    OnlyShowIn=XFCE;
  '';
  configureDock = pkgs.writeShellApplication {
    name = "blix-xfce-dock";
    runtimeInputs = [ pkgs.xfconf pkgs.xfce4-panel ];
    text = ''
      restart_panel=0
      for number in 12 17; do
        if xfconf-query -c xfce4-panel -p "/plugins/plugin-$number" >/dev/null 2>&1; then
          restart_panel=1
        fi
      done
      xfconf-query -c xfce4-panel -p /plugins/plugin-13/items -a -t string -s blix-terminal.desktop
      xfconf-query -c xfce4-panel -p /plugins/plugin-14/items -a -t string -s blix-files.desktop
      xfconf-query -c xfce4-panel -p /plugins/plugin-15/items -a -t string -s blix-firefox.desktop
      xfconf-query -c xfce4-panel -p /plugins/plugin-16/items -a -t string -s blix-applications.desktop
      # Omit the leading and trailing separator plugins from the dock.
      xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids -a \
        -t int -s 13 -t int -s 14 -t int -s 15 -t int -s 16
      xfconf-query -c xfce4-panel -p /plugins/plugin-12 -r 2>/dev/null || true
      xfconf-query -c xfce4-panel -p /plugins/plugin-17 -r 2>/dev/null || true
      if (( restart_panel )); then
        xfce4-panel -r
      fi
    '';
  };
in
{
  xdg.configFile = {
    "xfce4/panel/launcher-13/blix-terminal.desktop" = {
      force = true;
      text = launcher "Terminal" "${pkgs.xfce4-exo}/bin/exo-open --launch TerminalEmulator"
        ./xfce-dock-icons/terminal.png;
    };
    "xfce4/panel/launcher-14/blix-files.desktop" = {
      force = true;
      text = launcher "Files" "${pkgs.xfce4-exo}/bin/exo-open --launch FileManager %u"
        ./xfce-dock-icons/files.png;
    };
    "xfce4/panel/launcher-15/blix-firefox.desktop" = {
      force = true;
      text = launcher "Web Browser" "${pkgs.xfce4-exo}/bin/exo-open --launch WebBrowser %u"
        ../../home/przvl/config/labwc/icons/firefox.svg;
    };
    "xfce4/panel/launcher-16/blix-applications.desktop" = {
      force = true;
      text = launcher "Applications" "${pkgs.xfce4-appfinder}/bin/xfce4-appfinder"
        ./xfce-dock-icons/applications.png;
    };
    "autostart/blix-xfce-dock.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Blix XFCE dock
      Exec=${configureDock}/bin/blix-xfce-dock
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-Phase=Applications
    '';
  };
}
