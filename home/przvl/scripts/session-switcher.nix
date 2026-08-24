{ pkgs }:

pkgs.writeShellApplication {
  name = "blix-switch-session";
  runtimeInputs = with pkgs; [
    coreutils
    libnotify
    systemd
  ];
  text = ''
    session_id=''${XDG_SESSION_ID:-}
    if [ -z "$session_id" ]; then
      notify-send "Session switch failed" "The current login session could not be identified."
      exit 1
    fi

    # Ask the active desktop's logind-aware locker to secure this session.
    # Do not reveal the greeter until the locker confirms that it is active;
    # otherwise returning to this session could briefly expose it unlocked.
    loginctl lock-session "$session_id"

    for _ in $(seq 1 100); do
      locked=false
      case ''${XDG_CURRENT_DESKTOP:-} in
        *XFCE*)
          screensaver_state=$(busctl call \
            --user \
            org.xfce.ScreenSaver \
            /org/xfce/ScreenSaver \
            org.xfce.ScreenSaver \
            GetActive 2>/dev/null || true)
          if [ "$screensaver_state" = "b true" ]; then
            locked=true
          fi
          ;;
        *)
          if [ "$(loginctl show-session "$session_id" --property=LockedHint --value)" = "yes" ]; then
            locked=true
          fi
          ;;
      esac

      if "$locked"; then
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
