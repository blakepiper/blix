{ pkgs }:

# Wayland hands the gamma ramps back as soon as the client that set them
# disconnects, so a warm screen is a process that has to stay running. This
# script only records which mode is wanted and maps it to a temperature;
# services/night-mode.nix owns the process, through `night-mode run`.
pkgs.writeShellScriptBin "night-mode" ''
  night_temperature=3500
  night_plus_temperature=2200

  state_file="$XDG_RUNTIME_DIR/night-mode"
  mode="$(cat "$state_file" 2>/dev/null || printf 'off')"

  case "$1" in
    run)
      case "$mode" in
        night) temperature=$night_temperature ;;
        night-plus) temperature=$night_plus_temperature ;;
        *) exit 0 ;;
      esac
      exec ${pkgs.gammastep}/bin/gammastep -m wayland -P -O "$temperature"
      ;;
    next)
      case "$mode" in
        off) mode=night ;;
        night) mode=night-plus ;;
        *) mode=off ;;
      esac
      printf '%s\n' "$mode" > "$state_file"
      # Restarting re-reads the state file above, so the running temperature
      # always matches the mode that was just written.
      if [ "$mode" = off ]; then
        ${pkgs.systemd}/bin/systemctl --user stop night-mode.service
      else
        ${pkgs.systemd}/bin/systemctl --user restart night-mode.service
      fi
      ;;
  esac

  case "$mode" in
    night)
      icon=ld-moon-symbolic
      tooltip="Night mode: $night_temperature K"
      ;;
    night-plus)
      icon=ld-eclipse-symbolic
      tooltip="Night+ mode: $night_plus_temperature K"
      ;;
    *)
      mode=off
      icon=ld-sun-symbolic
      tooltip='Night mode: off'
      ;;
  esac

  printf '{"alt":"%s","tooltip":"%s"}\n' "$mode" "$tooltip"
''
