{ pkgs }:

pkgs.writeShellScriptBin "night-mode" ''
  state_file="$XDG_RUNTIME_DIR/night-mode"
  mode="$(cat "$state_file" 2>/dev/null || printf 'off')"

  case "$1" in
    next)
      case "$mode" in
        off)
          mode=night
          ${pkgs.hyprland}/bin/hyprctl hyprsunset temperature 3500
          ;;
        night)
          mode=night-plus
          ${pkgs.hyprland}/bin/hyprctl hyprsunset temperature 2200
          ;;
        *)
          mode=off
          ${pkgs.hyprland}/bin/hyprctl hyprsunset identity
          ;;
      esac
      printf '%s\n' "$mode" > "$state_file"
      ;;
  esac

  case "$mode" in
    night) tooltip='Night mode: 3500 K' ;;
    night-plus) tooltip='Night+ mode: 2200 K' ;;
    *) mode=off; tooltip='Night mode: off' ;;
  esac
  printf '{"alt":"%s","tooltip":"%s"}\n' "$mode" "$tooltip"
''
