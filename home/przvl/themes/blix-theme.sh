
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/blix"
themes_dir="$config_dir/themes"
current_link="$config_dir/current"

die() {
    printf 'blix-theme: %s\n' "$1" >&2
    exit 1
}

usage() {
    cat >&2 <<'USAGE'
Usage: blix-theme <command>

  list       Print "name<TAB>label" for every installed theme
  current    Print the name of the active theme
  status     Print the Wayle widget payload as JSON
  set NAME   Switch to NAME and apply it everywhere
  menu       Choose a theme from a list, then apply it
  apply      Re-apply the active theme to the running session
  reload     Apply, and restart the bar so it picks up new colors
  ensure     Create the active-theme link if it is missing
USAGE
    exit 64
}

theme_names() {
    local path
    for path in "$themes_dir"/*/; do
        [ -d "$path" ] || continue
        basename "$path"
    done
}

# Read one theme's label without leaking its variables into the caller.
theme_label() {
    (
        LABEL=$1
        # shellcheck disable=SC1090,SC1091
        . "$themes_dir/$1/meta.sh"
        printf '%s\n' "$LABEL"
    )
}

current_theme() {
    local name=""
    if [ -L "$current_link" ]; then
        name=$(basename "$(readlink "$current_link")")
    fi
    if [ -n "$name" ] && [ -d "$themes_dir/$name" ]; then
        printf '%s\n' "$name"
    else
        printf '%s\n' "$DEFAULT_THEME"
    fi
}

link_theme() {
    [ -d "$themes_dir/$1" ] || die "unknown theme: $1"
    mkdir -p "$config_dir"
    rm -f "$current_link.new"
    ln -sfn "$themes_dir/$1" "$current_link.new"
    mv -Tf "$current_link.new" "$current_link"
}

# Apply the parts of a theme that are set by command rather than read from a
# file. Every step is best-effort: switching themes must not fail because one
# component is not running.
# shellcheck disable=SC2154  # the colors come from the sourced meta.sh
apply_theme() {
    local dir reply
    dir="$themes_dir/$(current_theme)"
    [ -r "$dir/meta.sh" ] || die "active theme has no meta.sh"
    # shellcheck disable=SC1090,SC1091
    . "$dir/meta.sh"

    # hyprctl exits 0 even when the compositor rejects the request, so the
    # reply has to be inspected rather than the status.
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -r "$dir/hyprland.lua" ]; then
        reply=$(hyprctl eval "$(cat "$dir/hyprland.lua")" 2>&1) || true
        case "$reply" in
            ok*) ;;
            *) printf 'blix-theme: hyprland: %s\n' "$reply" >&2 ;;
        esac
    fi

    # hyprpaper reads its own config at start-up, so this only matters for a
    # theme switch inside a running session.
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -n "${WALLPAPER:-}" ]; then
        # hyprpaper answers with an empty string on success, hyprland with "ok".
        reply=$(hyprctl hyprpaper wallpaper ",$WALLPAPER,cover" 2>&1) || true
        case "$reply" in
            ok* | "") ;;
            *) printf 'blix-theme: hyprpaper: %s\n' "$reply" >&2 ;;
        esac
    fi

    gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" || true
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" || true
}

reload_theme() {
    apply_theme
    systemctl --user restart wayle.service || true
}

pick_theme() {
    local names labels name choice index
    mapfile -t names < <(theme_names)
    [ "${#names[@]}" -gt 0 ] || die "no themes installed"

    labels=""
    for name in "${names[@]}"; do
        labels="$labels$(theme_label "$name")"$'\n'
    done

    choice=$(printf '%s' "$labels" |
        fuzzel --dmenu --hide-prompt --lines "${#names[@]}" --width 24) || return 0
    [ -n "$choice" ] || return 0

    for index in "${!names[@]}"; do
        if [ "$(theme_label "${names[$index]}")" = "$choice" ]; then
            link_theme "${names[$index]}"
            reload_theme
            return 0
        fi
    done
    die "no theme matches: $choice"
}

main() {
    case "${1:-}" in
        list)
            local names name
            mapfile -t names < <(theme_names)
            for name in "${names[@]}"; do
                printf '%s\t%s\n' "$name" "$(theme_label "$name")"
            done
            ;;
        current) current_theme ;;
        status)
            local name
            name=$(current_theme)
            printf '{"alt":"%s","tooltip":"Theme: %s"}\n' "$name" "$(theme_label "$name")"
            ;;
        set)
            [ $# -eq 2 ] || usage
            link_theme "$2"
            reload_theme
            ;;
        menu) pick_theme ;;
        apply) apply_theme ;;
        reload) reload_theme ;;
        ensure)
            # Runs during home-manager activation, so it must never fail: a
            # missing theme is a cosmetic problem, a failed activation is not.
            local name
            [ -d "$current_link" ] && exit 0
            if [ ! -d "$themes_dir" ]; then
                printf 'blix-theme: no themes installed at %s yet\n' "$themes_dir" >&2
                exit 0
            fi
            name=$(current_theme)
            [ -d "$themes_dir/$name" ] || name=$(theme_names | head -n 1)
            if [ -z "$name" ]; then
                printf 'blix-theme: no themes installed; nothing to link\n' >&2
                exit 0
            fi
            link_theme "$name"
            ;;
        *) usage ;;
    esac
}

main "$@"
