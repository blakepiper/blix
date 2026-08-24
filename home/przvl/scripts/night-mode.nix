{ pkgs }:

pkgs.writeShellScriptBin "night-mode" ''
  state_file="$XDG_RUNTIME_DIR/night-mode"
  mode="$(cat "$state_file" 2>/dev/null || printf 'off')"

  set_temperature() {
    if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      case "$1" in
        off) ${pkgs.hyprland}/bin/hyprctl hyprsunset identity ;;
        *) ${pkgs.hyprland}/bin/hyprctl hyprsunset temperature "$1" ;;
      esac
    elif [ -n "''${DISPLAY:-}" ]; then
      case "$1" in
        off) ${pkgs.redshift}/bin/redshift -x ;;
        *) ${pkgs.redshift}/bin/redshift -P -O "$1" ;;
      esac
    fi
  }

  case "$1" in
    next)
      case "$mode" in
        off)
          mode=night
          set_temperature 3500
          ;;
        night)
          mode=night-plus
          set_temperature 2200
          ;;
        *)
          mode=off
          set_temperature off
          ;;
      esac
      printf '%s\n' "$mode" > "$state_file"
      ;;
  esac

  case "$mode" in
    night)
      icon=ld-moon-symbolic
      tooltip='Night mode: 3500 K'
      ;;
    night-plus)
      icon=ld-eclipse-symbolic
      tooltip='Night+ mode: 2200 K'
      ;;
    *)
      mode=off
      icon=ld-sun-symbolic
      tooltip='Night mode: off'
      ;;
  esac

  if [ "$1" = genmon ]; then
    printf '<icon>%s</icon><iconclick>%s next</iconclick><tool>%s</tool>\n' "$icon" "$0" "$tooltip"
  else
    printf '{"alt":"%s","tooltip":"%s"}\n' "$mode" "$tooltip"
  fi
''
