{ lib, pkgs, ... }:

let
  configureXfceDisplay = pkgs.writeShellApplication {
    name = "blix-configure-zen-xfce-display";
    runtimeInputs = [ pkgs.xrandr ];
    text = ''
      xrandr --output eDP-1 --mode 2880x1800 --rate 120
    '';
  };
in
{
  blix.monitors = [ ];

  # The 14-inch 2880x1800 panel is about 242 PPI. Keep it at its native mode
  # while presenting an effective 1440x900 desktop in Xfce.
  xfconf.settings.xsettings = {
    "Gdk/WindowScalingFactor" = lib.mkForce 2;
    "Xft/DPI" = lib.mkForce 96;
  };

  xdg.configFile."autostart/blix-zen-xfce-display.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Configure Zen Xfce display
    Exec=${configureXfceDisplay}/bin/blix-configure-zen-xfce-display
    OnlyShowIn=XFCE;
    X-GNOME-Autostart-enabled=true
  '';
}
