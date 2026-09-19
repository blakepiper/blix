{ config, lib, pkgs, hardwareHotplug, ... }:

let
  wallpaper = config.blix.display.wallpaper;
in
{
  home.sessionVariables = {
    BLIX_INTERNAL_OUTPUT = config.blix.display.internalOutput;
    BLIX_EXTERNAL_OUTPUT = config.blix.display.externalOutput;
    BLIX_MIRROR_MODE = config.blix.display.mirrorMode;
    BLIX_MIRROR_RATE = config.blix.display.mirrorRate;
  };

  home.file = {
    ".config/fastfetch/config.jsonc".source = ./config/fastfetch/config.jsonc;
    ".config/mimeapps.list".source = ./config/mimeapps.list;
    ".config/nvim".source = ./config/nvim;
    ".config/oxwm/config.lua".source = ./config/oxwm/config.lua;
    ".config/picom/picom.conf".source = ./config/picom/picom.conf;
    ".config/tmux/tmux.conf".source = ./config/tmux/tmux.conf;
    "Pictures/Screenshots/.keep".text = "";
  };

  # Xfe rewrites xferc with mutable layout, history, and keybinding state;
  # preserve that user-owned file instead of clobbering it on activation.

  # This is intentionally a manual startx session. Auxiliary services are
  # started before OXWM, but none of them may prevent the window manager from
  # appearing if a lock/compositor helper is temporarily unavailable.
  home.file.".xinitrc" = {
    executable = true;
    text = ''
    #!${pkgs.bash}/bin/bash
    # Import the standard NixOS X11 hooks when present.
    if [[ -d /etc/X11/xinit/xinitrc.d ]]; then
      for hook in /etc/X11/xinit/xinitrc.d/?*.sh; do
        [[ ! -x $hook ]] || source "$hook"
      done
    fi

    export PATH="${config.home.path}/bin:${pkgs.systemd}/bin:${pkgs.coreutils}/bin:$PATH"
    export XDG_CURRENT_DESKTOP=OXWM
    export XDG_SESSION_TYPE=x11
    export CM_LAUNCHER=dmenu
    export CM_SELECTIONS=clipboard
    export CM_MAX_CLIPS=100
    export CM_OWN_CLIPBOARD=0
    export BLIX_INTERNAL_OUTPUT=${lib.escapeShellArg config.blix.display.internalOutput}
    export BLIX_EXTERNAL_OUTPUT=${lib.escapeShellArg config.blix.display.externalOutput}
    export BLIX_MIRROR_MODE=${lib.escapeShellArg config.blix.display.mirrorMode}
    export BLIX_MIRROR_RATE=${lib.escapeShellArg config.blix.display.mirrorRate}
    export BLIX_BATTERY=

    for battery in /sys/class/power_supply/*; do
      [[ -r $battery/type ]] || continue
      if [[ $(${pkgs.coreutils}/bin/cat "$battery/type") == Battery ]]; then
        BLIX_BATTERY=$(${pkgs.coreutils}/bin/basename "$battery")
        break
      fi
    done

    ${pkgs.xsetroot}/bin/xsetroot -solid '#1a1b26'
    ${hardwareHotplug}/bin/blix-hardware-hotplug --once
    # Reapply after hardware-specific XKB setup so it remains effective in
    # the manually started session.
    ${pkgs.xset}/bin/xset r rate 200 50
${lib.optionalString (wallpaper != null) ''
    if [[ -r ${lib.escapeShellArg wallpaper} ]]; then
      ${pkgs.feh}/bin/feh --no-fehbg --bg-fill ${lib.escapeShellArg wallpaper} >/dev/null 2>&1 || true
    fi
''}

    # No idle locking or automatic display blanking. Manual DPMS remains
    # available through the control menu and logind suspend still locks.
    ${pkgs.xset}/bin/xset s off
    ${pkgs.xset}/bin/xset +dpms
    ${pkgs.xset}/bin/xset dpms 0 0 0

    if [[ -z ''${XDG_SESSION_ID:-} ]]; then
      XDG_SESSION_ID=$(${pkgs.systemd}/bin/loginctl show-session self -p Id --value) || exit 1
      export XDG_SESSION_ID
    fi
    [[ -n $XDG_SESSION_ID ]] || {
      echo 'No local logind session; cannot arrange suspend locking.' >&2
      exit 1
    }

    cleanup() {
      ${pkgs.systemd}/bin/systemctl --user stop blix-session.target >/dev/null 2>&1 || true
    }
    trap cleanup EXIT

    ${pkgs.systemd}/bin/systemctl --user import-environment \
      DISPLAY XAUTHORITY PATH XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID \
      BLIX_INTERNAL_OUTPUT BLIX_EXTERNAL_OUTPUT BLIX_MIRROR_MODE BLIX_MIRROR_RATE
    ${pkgs.systemd}/bin/systemctl --user daemon-reload
    if ! ${pkgs.systemd}/bin/systemctl --user start --no-block blix-session.target; then
      echo 'Warning: unable to start all Blix session services; continuing with OXWM.' >&2
    fi

    ready=false
    for ((attempt = 0; attempt < 50; attempt++)); do
      lock_pid=$(${pkgs.systemd}/bin/systemctl --user show blix-lock.service -p MainPID --value)
      if ${pkgs.systemd}/bin/busctl --timeout=2 --json=short call \
        org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager ListInhibitors |
        ${pkgs.jq}/bin/jq -e --argjson pid "''${lock_pid:-0}" \
          '.data[0][] | select(.[5] == $pid and .[3] == "delay" and (.[0] | split(":") | index("sleep")))' >/dev/null; then
        ready=true
        break
      fi
      if ! ${pkgs.systemd}/bin/systemctl --user is-active --quiet blix-lock.service; then
        lock_state=$(${pkgs.systemd}/bin/systemctl --user show blix-lock.service -p ActiveState --value)
        [[ $lock_state == activating ]] || break
      fi
      ${pkgs.coreutils}/bin/sleep 0.1
    done

    if ! "$ready"; then
      echo 'Warning: no suspend-lock inhibitor; inspect journalctl --user -u blix-lock.service.' >&2
    fi

    ${pkgs.oxwm}/bin/oxwm
  '';
  };
}
