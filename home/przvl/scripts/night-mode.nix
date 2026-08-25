{ pkgs }:

pkgs.writeShellScriptBin "night-mode" ''
  state_file="$XDG_RUNTIME_DIR/night-mode"
  mode="$(cat "$state_file" 2>/dev/null || printf 'off')"

  set_temperature() {
    case "$1" in
      off) ${pkgs.hyprland}/bin/hyprctl hyprsunset identity ;;
      *) ${pkgs.hyprland}/bin/hyprctl hyprsunset temperature "$1" ;;
    esac
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

  printf '{"alt":"%s","tooltip":"%s"}\n' "$mode" "$tooltip"
''
