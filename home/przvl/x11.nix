{ config, lib, pkgs, displayHotplug, oxwmVolume, oxwmBrightness, blixSettings, ... }:

let
  display = config.blix.display;
  wallpaper = config.blix.display.wallpaper;
  primaryScaleFrom = config.blix.display.primaryScaleFrom;
  nixosLogo = pkgs.runCommand "blix-bar-nixos-logo.xpm" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    magick ${pkgs.nixos-icons}/share/icons/hicolor/24x24/apps/nix-snowflake.png \
      -resize 20x20 -background '#1a1b26' -alpha remove -alpha off "xpm:$out"
  '';
  # One environment feeds shell startup, the X session and the hotplug unit.
  displayEnvironment = {
    BLIX_DISPLAY_LAYOUT = display.layout;
    BLIX_PRIMARY_OUTPUT = display.primaryOutput;
    BLIX_PRIMARY_ROTATION = display.primaryRotation;
    BLIX_DISPLAY_DPI = if display.dpi == null then "" else toString display.dpi;
    BLIX_EXTERNAL_OUTPUT = if display.externalOutput == null then "" else display.externalOutput;
    BLIX_ADDITIONAL_EXTERNAL_OUTPUTS = lib.concatStringsSep " " display.additionalExternalOutputs;
    BLIX_MIRROR_MODE = display.mirrorMode;
    BLIX_MIRROR_RATE = if display.mirrorRate == null then "" else display.mirrorRate;
    BLIX_PRIMARY_SCALE_FROM = if primaryScaleFrom == null then "" else primaryScaleFrom;
    BLIX_WALLPAPER = if wallpaper == null then "" else wallpaper;
  };
  sessionSettings = pkgs.writeShellApplication {
    name = "blix-session-settings";
    runtimeInputs = [ pkgs.xset ] ++ lib.optional (display.dpi != null) pkgs.xrdb;
    text = ''
      xset r rate 200 50
      xset s off
      xset +dpms
      xset dpms 0 0 ${toString display.blankAfterSeconds}
    '' + lib.optionalString (display.dpi != null) ''
      xrdb -merge ${config.home.file.${config.xresources.path}.source}
    '' + ''
      # The flake provides defaults; restore user choices after those defaults.
      ${blixSettings}/bin/blix-settings-apply apply-session
    '';
  };
in
{
  _module.args = {
    blixDisplayEnvironment = displayEnvironment;
    blixSessionSettings = sessionSettings;
  };

  # Firefox needs XInput2 scroll events for native two-finger history swipes.
  home.sessionVariables = displayEnvironment // { MOZ_USE_XINPUT2 = "1"; };
  xresources.properties = lib.mkIf (display.dpi != null) { "Xft.dpi" = display.dpi; };

  # Manual Gammastep commands should use X11 instead of probing Wayland first.
  xdg.configFile."gammastep/config.ini".text = ''
    [general]
    adjustment-method=randr
  '';

  home.file = {
    ".config/mimeapps.list".source = ./config/mimeapps.list;
    ".config/oxwm/config.lua".text = lib.replaceStrings
      [ "@nixos-logo@" "@oxwm-volume@" "@oxwm-brightness@" "@wpctl@" "@brightnessctl@" "@blix-settings@" ]
      [ "${nixosLogo}" "${oxwmVolume}/bin/oxwm-volume" "${oxwmBrightness}/bin/oxwm-brightness" "${pkgs.wireplumber}/bin/wpctl" "${pkgs.brightnessctl}/bin/brightnessctl" "${blixSettings}/bin/blix-settings" ]
      (builtins.readFile ./config/oxwm/config.lua);
    ".config/picom/picom.conf" = {
      source = ./config/picom/picom.conf;
      onChange = "${pkgs.systemd}/bin/systemctl --user try-restart blix-picom.service";
    };
    "Pictures/Screenshots/.keep".text = "";
  };

  # This is intentionally a manual startx session. Auxiliary services are
  # started before OXWM, but none of them may prevent the window manager from
  # appearing if a lock/compositor helper is temporarily unavailable.
  home.file.".xinitrc" = {
    executable = true;
    text = "#!${pkgs.bash}/bin/bash\n" + ''
    # Import the standard NixOS X11 hooks when present.
    if [[ -d /etc/X11/xinit/xinitrc.d ]]; then
      for hook in /etc/X11/xinit/xinitrc.d/?*.sh; do
        [[ ! -x $hook ]] || source "$hook"
      done
    fi

    # Follow profile switches instead of retaining this session's package generation.
    export PATH="${config.home.profileDirectory}/bin:${pkgs.systemd}/bin:${pkgs.coreutils}/bin:$PATH"
    export XDG_CURRENT_DESKTOP=OXWM
    export XDG_SESSION_TYPE=x11
    export MOZ_USE_XINPUT2=1
    export TERMINAL=${lib.escapeShellArg config.home.sessionVariables.TERMINAL}
    export BROWSER=${lib.escapeShellArg config.home.sessionVariables.BROWSER}
    export CM_LAUNCHER=dmenu
    export CM_SELECTIONS=clipboard
    export CM_MAX_CLIPS=100
    export CM_OWN_CLIPBOARD=0
${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
  "    export ${name}=${lib.escapeShellArg value}"
) displayEnvironment)}
    export BLIX_BATTERY=
    export BLIX_HAS_BACKLIGHT=${if config.blix.hardware.hasBacklight then "1" else "0"}

${lib.optionalString config.blix.hardware.hasBattery ''
    for battery in /sys/class/power_supply/*; do
      [[ -r $battery/type ]] || continue
      if [[ $(${pkgs.coreutils}/bin/cat "$battery/type") == Battery ]]; then
        BLIX_BATTERY=$(${pkgs.coreutils}/bin/basename "$battery")
        break
      fi
    done
''}

    ${pkgs.xsetroot}/bin/xsetroot -solid '#1a1b26'
    ${displayHotplug}/bin/blix-display-hotplug --once
    # Apply the same repeat, blanking and DPI settings on startup and rebuilds.
    ${sessionSettings}/bin/blix-session-settings
${lib.optionalString (wallpaper != null) ''
    if [[ -r ${lib.escapeShellArg wallpaper} ]]; then
      ${pkgs.feh}/bin/feh --no-fehbg --bg-fill ${lib.escapeShellArg wallpaper} >/dev/null 2>&1 || true
    fi
''}

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
      DISPLAY XAUTHORITY PATH BROWSER MOZ_USE_XINPUT2 XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID \
      ${lib.concatStringsSep " " (builtins.attrNames displayEnvironment)}
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
