# External monitors use DDC/CI rather than the laptop backlight interface.
{ pkgs, ... }:

let
  brightness = pkgs.writeShellApplication {
    name = "blix-monitor-brightness";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./monitor-brightness.py} ${pkgs.ddcutil}/bin/ddcutil "$@"
    '';
  };
in
{
  blix.wayland.brightnessCommand = "${brightness}/bin/blix-monitor-brightness";
  home.packages = [ brightness ];
  systemd.user.services.blix-monitor-brightness = {
    Unit = {
      Description = "Coalesce monitor brightness updates outside the window manager";
      PartOf = [ "blix-session.target" "blix-wayland-session.target" ];
    };
    Service = {
      ExecStart = "${brightness}/bin/blix-monitor-brightness serve";
      RuntimeDirectory = "blix-monitor-brightness";
      RuntimeDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "blix-session.target" "blix-wayland-session.target" ];
  };
  systemd.user.targets.blix-wayland-session.Unit.Wants = [ "blix-monitor-brightness.service" ];
  _module.args.oxwmBrightnessBarBlocks = ''
    table.insert(blocks, oxwm.bar.block.shell({
      format = "Bri {}",
      command = "${brightness}/bin/blix-monitor-brightness",
      interval = 1,
      color = colors.status.brightness,
      underline = false,
      click = {
        command = "${brightness}/bin/blix-monitor-brightness {}",
        slider = { label = "Brightness", min = 1, max = 100 },
      },
    }))
    table.insert(blocks, oxwm.bar.block.static({
      text = "│",
      color = colors.status.separator,
      underline = false,
    }))
  '';
}
