{ pkgs, blixTheme, nightMode, currentThemeDir }:

pkgs.writeShellApplication {
  name = "blix-xfce-bar-widget";
  runtimeInputs = [ pkgs.brightnessctl pkgs.coreutils pkgs.yad ];
  text = ''
    presentation_property=/xfce4-power-manager/presentation-mode
    theme_meta=${currentThemeDir}/meta.sh

    format_label() {
      label=$1
      FOREGROUND=
      if [ -r "$theme_meta" ]; then
        # shellcheck source=/dev/null
        . "$theme_meta"
      fi
      case "''${FOREGROUND:-}" in
        \#??????) printf '<span foreground="%s">%s</span>' "$FOREGROUND" "$label" ;;
        *) printf '%s' "$label" ;;
      esac
    }

    read_brightness() {
      value=$(brightnessctl --machine-readable 2>/dev/null \
        | head -n 1 \
        | cut -d, -f4 \
        | tr -d '%')
      case "$value" in
        ""|*[!0-9]*) printf '0\n' ;;
        *) printf '%s\n' "$value" ;;
      esac
    }

    case "''${1:-}" in
      night)
        mode=$(cat "$XDG_RUNTIME_DIR/night-mode" 2>/dev/null || printf off)
        case "$mode" in
          night)
            icon=night-light-symbolic
            label='Night 3500K'
            tooltip='Night mode: 3500 K'
            ;;
          night-plus)
            icon=weather-clear-night-symbolic
            label='Night 2200K'
            tooltip='Night+ mode: 2200 K'
            ;;
          *)
            icon=night-light-disabled-symbolic
            label='Night off'
            tooltip='Night mode: off'
            ;;
        esac
        formatted=$(format_label "$label")
        printf '<icon>%s</icon><iconclick>%s next</iconclick><txt>%s</txt><txtclick>%s next</txtclick><tool>%s</tool>\n' \
          "$icon" ${nightMode}/bin/night-mode "$formatted" ${nightMode}/bin/night-mode "$tooltip"
        ;;
      idle)
        state=$(${pkgs.xfconf}/bin/xfconf-query \
          --channel xfce4-power-manager \
          --property "$presentation_property" 2>/dev/null || printf false)
        if [ "$state" = true ]; then
          icon=changes-prevent-symbolic
          label='Idle blocked'
          tooltip='Idle inhibition: indefinite'
        else
          icon=changes-allow-symbolic
          label='Idle allowed'
          tooltip='Idle inhibition: off'
        fi
        formatted=$(format_label "$label")
        printf '<icon>%s</icon><iconclick>%s idle-toggle</iconclick><txt>%s</txt><txtclick>%s idle-toggle</txtclick><tool>%s</tool>\n' \
          "$icon" "$0" "$formatted" "$0" "$tooltip"
        ;;
      idle-toggle)
        state=$(${pkgs.xfconf}/bin/xfconf-query \
          --channel xfce4-power-manager \
          --property "$presentation_property" 2>/dev/null || printf false)
        if [ "$state" = true ]; then next=false; else next=true; fi
        if ${pkgs.xfconf}/bin/xfconf-query \
          --channel xfce4-power-manager \
          --property "$presentation_property" >/dev/null 2>&1; then
          ${pkgs.xfconf}/bin/xfconf-query \
            --channel xfce4-power-manager \
            --property "$presentation_property" \
            --set "$next"
        else
          ${pkgs.xfconf}/bin/xfconf-query \
            --channel xfce4-power-manager \
            --property "$presentation_property" \
            --create --type bool --set "$next"
        fi
        ;;
      theme)
        current=$(${blixTheme}/bin/blix-theme current)
        label=$current
        while IFS=$'\t' read -r name candidate; do
          if [ "$name" = "$current" ]; then
            label=$candidate
            break
          fi
        done < <(${blixTheme}/bin/blix-theme list)
        formatted=$(format_label Theme)
        printf '<icon>applications-graphics-symbolic</icon><iconclick>%s menu</iconclick><txt>%s</txt><txtclick>%s menu</txtclick><tool>Theme picker: %s</tool>\n' \
          ${blixTheme}/bin/blix-theme "$formatted" ${blixTheme}/bin/blix-theme "$label"
        ;;
      brightness)
        value=$(read_brightness)
        formatted=$(format_label "Brightness $value%")
        printf '<icon>display-brightness-symbolic</icon><iconclick>%s brightness-menu</iconclick><txt>%s</txt><txtclick>%s brightness-menu</txtclick><tool>Brightness: %s%%</tool>\n' \
          "$0" "$formatted" "$0" "$value"
        ;;
      brightness-menu)
        current=$(read_brightness)
        yad \
          --scale \
          --value="$current" \
          --min-value=1 \
          --max-value=100 \
          --step=1 \
          --print-partial \
          --text=Brightness \
          --undecorated \
          --no-buttons \
          --close-on-unfocus \
          --skip-taskbar \
          --mouse \
          --width=320 \
          --height=80 \
        | while IFS= read -r value; do
            value=''${value%%.*}
            if [ -n "$value" ]; then
              brightnessctl -e4 -n2 set "$value%" >/dev/null
            fi
          done
        ;;
      *)
        printf 'usage: blix-xfce-bar-widget {night|idle|idle-toggle|theme|brightness|brightness-menu}\n' >&2
        exit 64
        ;;
    esac
  '';
}
