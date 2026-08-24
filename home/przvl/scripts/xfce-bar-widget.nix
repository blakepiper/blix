{ pkgs, blixTheme, nightMode }:

pkgs.writeShellApplication {
  name = "blix-xfce-bar-widget";
  runtimeInputs = [ pkgs.brightnessctl pkgs.coreutils pkgs.yad ];
  text = ''
    presentation_property=/xfce4-power-manager/presentation-mode

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
            tooltip='Night mode: 3500 K'
            ;;
          night-plus)
            icon=weather-clear-night-symbolic
            tooltip='Night+ mode: 2200 K'
            ;;
          *)
            icon=night-light-disabled-symbolic
            tooltip='Night mode: off'
            ;;
        esac
        printf '<icon>%s</icon><iconclick>%s next</iconclick><tool>%s</tool>\n' \
          "$icon" ${nightMode}/bin/night-mode "$tooltip"
        ;;
      idle)
        state=$(${pkgs.xfconf}/bin/xfconf-query \
          --channel xfce4-power-manager \
          --property "$presentation_property" 2>/dev/null || printf false)
        if [ "$state" = true ]; then
          icon=tb-coffee-symbolic
          tooltip='Keep awake: on (suspend and hibernation inhibited)'
        else
          icon=tb-coffee-off-symbolic
          tooltip='Keep awake: off'
        fi
        printf '<icon>%s</icon><iconclick>%s idle-toggle</iconclick><tool>%s</tool>\n' \
          "$icon" "$0" "$tooltip"
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
        printf '<icon>applications-graphics-symbolic</icon><iconclick>%s menu</iconclick><tool>Theme picker: %s</tool>\n' \
          ${blixTheme}/bin/blix-theme "$label"
        ;;
      brightness)
        value=$(read_brightness)
        printf '<icon>display-brightness-symbolic</icon><iconclick>%s brightness-menu</iconclick><tool>Brightness: %s%%</tool>\n' \
          "$0" "$value"
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
