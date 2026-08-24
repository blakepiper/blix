{ pkgs, blixTheme }:

pkgs.writeShellApplication {
  name = "blix-xfce-bar-widget";
  text = ''
    presentation_property=/xfce4-power-manager/presentation-mode

    case "''${1:-}" in
      idle)
        state=$(${pkgs.xfconf}/bin/xfconf-query \
          --channel xfce4-power-manager \
          --property "$presentation_property" 2>/dev/null || printf false)
        if [ "$state" = true ]; then
          icon=changes-prevent-symbolic
          tooltip='Idle inhibition: indefinite'
        else
          icon=changes-allow-symbolic
          tooltip='Idle inhibition: off'
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
        printf '<icon>cm-theme-symbolic</icon><iconclick>%s menu</iconclick><tool>Theme: %s</tool>\n' \
          ${blixTheme}/bin/blix-theme "$label"
        ;;
      *)
        printf 'usage: blix-xfce-bar-widget {idle|idle-toggle|theme}\n' >&2
        exit 64
        ;;
    esac
  '';
}
