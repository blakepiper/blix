{ pkgs }:

pkgs.writeShellApplication {
  name = "blix-switch-session";
  runtimeInputs = with pkgs; [
    coreutils
    libnotify
    procps
    systemd
  ];
  text = ''
    session_id=''${XDG_SESSION_ID:-}
    if [ -z "$session_id" ]; then
      notify-send "Session switch failed" "The current login session could not be identified."
      exit 1
    fi

    # Each desktop reports that it is locked in its own way, so the check that
    # the session is really secured has to be picked per desktop.
    case ''${XDG_CURRENT_DESKTOP:-} in
      *Hyprland*)
        # hyprlock takes the session lock through ext-session-lock and never
        # calls logind's SetLockedHint, so LockedHint stays "no" for the whole
        # lock and polling it here only ever timed out. Watch for the locker
        # process instead.
        locked() { pgrep -x hyprlock >/dev/null; }
        # hyprlock copies the screen for its background before it takes the
        # lock, and that copy needs the compositor to still hold the display.
        # Give it time to finish and lock before the greeter takes the VT.
        settle=1
        ;;
      *XFCE*)
        locked() {
          screensaver_state=$(busctl call \
            --user \
            org.xfce.ScreenSaver \
            /org/xfce/ScreenSaver \
            org.xfce.ScreenSaver \
            GetActive 2>/dev/null || true)
          [ "$screensaver_state" = "b true" ]
        }
        settle=0
        ;;
      *)
        locked() {
          [ "$(loginctl show-session "$session_id" --property=LockedHint --value)" = "yes" ]
        }
        settle=0
        ;;
    esac

    # Ask the active desktop's logind-aware locker to secure this session.
    # Do not reveal the greeter until the locker confirms that it is active;
    # otherwise returning to this session could briefly expose it unlocked.
    loginctl lock-session "$session_id"

    for _ in $(seq 1 100); do
      if locked; then
        [ "$settle" = 0 ] || sleep "$settle"
        busctl call \
          --system \
          org.freedesktop.DisplayManager \
          /org/freedesktop/DisplayManager/Seat0 \
          org.freedesktop.DisplayManager.Seat \
          SwitchToGreeter
        exit 0
      fi
      sleep 0.05
    done

    notify-send "Session switch failed" "The desktop did not confirm that it was locked."
    exit 1
  '';
}
