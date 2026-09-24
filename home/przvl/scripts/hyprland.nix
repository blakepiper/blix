{ config, lib, pkgs }:

let
  target = "blix-hyprland-session.target";
  portals = "xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service";
in
rec {
  start = pkgs.writeShellApplication {
    name = "start-hyprland";
    runtimeInputs = [ pkgs.systemd pkgs.dbus pkgs.coreutils ];
    text = ''
      if [[ -n ''${DISPLAY:-} || -n ''${WAYLAND_DISPLAY:-} ]] ||
         systemctl --user is-active --quiet blix-session.target ${target}; then
        echo 'Exit the current desktop first, then run start-hyprland from a TTY.' >&2
        exit 1
      fi
      [[ $(tty) == /dev/tty[0-9]* ]] || {
        echo 'Run start-hyprland from a local TTY.' >&2
        exit 1
      }
      export XDG_SESSION_ID="''${XDG_SESSION_ID:-$(loginctl show-session self -p Id --value)}"
      export XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland
      export TERMINAL=foot MOZ_ENABLE_WAYLAND=1 NIXOS_OZONE_WL=1
      # Always tear helpers down, including when the compositor exits abnormally.
      # shellcheck disable=SC2329
      cleanup() {
        systemctl --user stop ${target} ${portals} || true
        dbus-update-activation-environment DISPLAY= WAYLAND_DISPLAY= HYPRLAND_INSTANCE_SIGNATURE= \
          XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP= XDG_SESSION_TYPE= TERMINAL=st \
          MOZ_ENABLE_WAYLAND= NIXOS_OZONE_WL= || true
        systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE \
          XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE TERMINAL MOZ_ENABLE_WAYLAND NIXOS_OZONE_WL || true
      }
      trap cleanup EXIT
      systemctl --user stop ${portals} || true
      ${pkgs.hyprland}/bin/start-hyprland "$@"
    '';
  };

  session = pkgs.writeShellApplication {
    name = "blix-hyprland-session";
    runtimeInputs = [ pkgs.systemd pkgs.dbus ];
    text = ''
      dbus-update-activation-environment --systemd \
        DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP \
        XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID PATH TERMINAL MOZ_ENABLE_WAYLAND NIXOS_OZONE_WL
      systemctl --user start ${target}
    '';
  };

  lock = pkgs.writeShellApplication {
    name = "blix-hyprland-lock";
    runtimeInputs = [ pkgs.util-linux pkgs.hyprlock ];
    text = ''
      # Multiple key presses and suspend requests must share one locker.
      exec 9>"$XDG_RUNTIME_DIR/blix-hyprland-lock.lock"
      flock -n 9 || exit 0
      hyprlock
    '';
  };

  clipboard = pkgs.writeShellApplication {
    name = "blix-hyprland-clipboard";
    runtimeInputs = [ pkgs.cliphist pkgs.fuzzel pkgs.wl-clipboard ];
    text = ''
      selection=$(cliphist list | fuzzel --dmenu --prompt 'Clipboard: ') || exit 0
      [[ -n $selection ]] || exit 0
      printf '%s\n' "$selection" | cliphist decode | wl-copy
    '';
  };

  screenshot = pkgs.writeShellApplication {
    name = "blix-hyprland-screenshot";
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.hyprland pkgs.jq pkgs.wl-clipboard pkgs.coreutils ];
    text = ''
      umask 077
      args=()
      case ''${1:-} in
        "") geometry=$(slurp) || exit 0; args=(-g "$geometry") ;;
        --full) ;;
        --window)
          geometry=$(hyprctl -j activewindow | jq -er '
            select(.mapped == true) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          args=(-g "$geometry") ;;
        *) echo 'Usage: blix-hyprland-screenshot [--full|--window]' >&2; exit 2 ;;
      esac
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      staging=$(mktemp "$directory/.capture.XXXXXXXX")
      trap 'rm -f -- "$staging"' EXIT
      grim "''${args[@]}" "$staging"
      file=$(mktemp --suffix=.png "$directory/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXXXX")
      mv -T -- "$staging" "$file"
      wl-copy --type image/png < "$file"
      printf '%s\n' "$file"
    '';
  };

  control = pkgs.writeShellApplication {
    name = "blix-hyprland-control";
    runtimeInputs = [ pkgs.fuzzel pkgs.systemd pkgs.hyprland pkgs.coreutils ];
    text = ''
      confirm() {
        local answer
        answer=$(printf 'No\nYes\n' | fuzzel --dmenu --prompt "$1 ") || return 1
        [[ $answer == Yes ]]
      }
      choice=$(printf 'Lock\nSuspend\nReboot\nLog Out\nMonitors Off\nPower Off\n' |
        fuzzel --dmenu --prompt 'Control: ') || exit 0
      case $choice in
        Lock) ${lock}/bin/blix-hyprland-lock ;;
        Suspend) systemctl suspend ;;
        Reboot) if confirm 'Reboot?'; then systemctl reboot; fi ;;
        'Log Out') if confirm 'Log out? Unsaved work may be lost.'; then hyprctl dispatch 'hl.dsp.exit()'; fi ;;
        'Monitors Off') sleep 0.2; hyprctl dispatch 'hl.dsp.dpms({action="off"})' ;;
        'Power Off') if confirm 'Power off?'; then systemctl poweroff; fi ;;
      esac
    '';
  };

  wallpaper = pkgs.writeShellApplication {
    name = "blix-hyprland-wallpaper";
    runtimeInputs = [ pkgs.swaybg ];
    text = ''
      wallpaper=${lib.escapeShellArg (if config.blix.display.wallpaper == null then "" else config.blix.display.wallpaper)}
      if [[ -n $wallpaper && -r $wallpaper ]]; then
        exec swaybg --image "$wallpaper" --mode fill --color '#1a1b26'
      fi
      exec swaybg --color '#1a1b26'
    '';
  };
}
