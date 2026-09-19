{ pkgs }:

let
  source = name: builtins.readFile (./../config/blix-bin + "/${name}");

  writeScript = name: runtimeInputs: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    text = source name;
  };

  blixLock = writeScript "blix-lock" [
    pkgs.systemd
    pkgs.xset
  ];

  xsecurelockWithoutPicom = pkgs.writeShellApplication {
    name = "xsecurelock-without-picom";
    runtimeInputs = [
      pkgs.systemd
      pkgs.xsecurelock
    ];
    text = ''
      set -u

      picom_was_active=false
      if systemctl --user is-active --quiet blix-picom.service; then
        picom_was_active=true
        if ! systemctl --user stop blix-picom.service; then
          echo 'Could not stop Blix Picom before locking.' >&2
          exit 1
        fi
      fi

      # The EXIT trap invokes this function indirectly.
      # shellcheck disable=SC2329
      restore_picom() {
        if "$picom_was_active" && systemctl --user is-active --quiet blix-session.target; then
          systemctl --user start blix-picom.service ||
            echo 'Could not restart Blix Picom after unlocking.' >&2
        fi
      }
      trap restore_picom EXIT

      exec_status=0
      ${pkgs.xsecurelock}/bin/xsecurelock "$@" || exec_status=$?
      exit "$exec_status"
    '';
  };

  lockService = pkgs.writeShellScript "blix-lock-service" ''
    exec ${pkgs.xss-lock}/bin/xss-lock \
      --transfer-sleep-lock \
      --session "''${XDG_SESSION_ID:?XDG_SESSION_ID is not set}" \
      -- ${xsecurelockWithoutPicom}/bin/xsecurelock-without-picom
  '';

  clipboardTextProbe = pkgs.writeShellScriptBin "xsel" ''
    # Do not ask an image-only selection for text. Large X11 image owners can
    # otherwise make clipmenud block while probing TARGETS.
    set -u

    selection=primary
    output_requested=0
    for arg in "$@"; do
      case "$arg" in
        -o|--output) output_requested=1 ;;
        -p|--primary) selection=primary ;;
        -s|--secondary) selection=secondary ;;
        -b|--clipboard) selection=clipboard ;;
      esac
    done

    if (( output_requested )); then
      targets=$(${pkgs.coreutils}/bin/timeout 1s ${pkgs.xclip}/bin/xclip \
        -selection "$selection" -out -target TARGETS 2>/dev/null) || exit 0

      has_text_target=1
      while IFS= read -r target; do
        case "$target" in
          UTF8_STRING|STRING|TEXT|COMPOUND_TEXT|text/plain|text/plain\;charset=utf-8|text/plain\;charset=UTF-8)
            has_text_target=0
            break
            ;;
        esac
      done <<< "$targets"

      (( has_text_target == 0 )) || exit 0
    fi

    exec ${pkgs.xsel}/bin/xsel "$@"
  '';

  hardwareHotplug = writeScript "blix-hardware-hotplug" [
    pkgs.coreutils
    pkgs.feh
    pkgs.gnugrep
    pkgs.gnused
    pkgs.systemd
    pkgs.setxkbmap
    pkgs.xkbcomp
    pkgs.xrandr
  ];

  fastfetchPackages = writeScript "blix-fastfetch-packages" [
    pkgs.coreutils
    pkgs.fastfetch
    pkgs.gnugrep
    pkgs.gnused
    pkgs.util-linux
  ];
in
{
  inherit
    clipboardTextProbe
    hardwareHotplug
    lockService
    blixLock
    xsecurelockWithoutPicom;

  scripts = [
    (writeScript "clipboard-history" [ pkgs.clipmenu pkgs.dmenu ])
    (writeScript "control-menu" [
      pkgs.coreutils
      pkgs.dmenu
      pkgs.systemd
      pkgs.xdotool
      pkgs.xset
      blixLock
    ])
    (writeScript "dev" [
      pkgs.coreutils
      pkgs.fastfetch
      pkgs.neovim
      pkgs.tmux
      pkgs.util-linux
    ])
    fastfetchPackages
    (writeScript "blix-brightness" [
      pkgs.brightnessctl
      pkgs.coreutils
    ])
    hardwareHotplug
    blixLock
    (writeScript "blix-stats" [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.mesa-demos
      pkgs.procps
      pkgs.systemd
      pkgs.util-linux
      pkgs.xrandr
    ])
    (writeScript "oxwm-battery" [ pkgs.coreutils ])
    (writeScript "oxwm-cpu" [
      pkgs.coreutils
      pkgs.gawk
    ])
    (writeScript "screenshot-region" [
      pkgs.coreutils
      pkgs.gawk
      pkgs.maim
      pkgs.xclip
      pkgs.xprop
    ])
    xsecurelockWithoutPicom
  ];
}
