# Separate XFCE login from the OXWM ~/.xinitrc and Blix session services.
{ pkgs, ... }:

let
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
  home.packages = [ start ];

  home.file.".xfce-xinitrc" = {
    executable = true;
    text = "#!${pkgs.bash}/bin/bash\n" + ''
      export XDG_CURRENT_DESKTOP=XFCE
      export XDG_SESSION_DESKTOP=xfce
      export XDG_SESSION_TYPE=x11
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

  systemd.user.targets.blix-xfce-session.Unit.Description = "Blix XFCE session";
}
