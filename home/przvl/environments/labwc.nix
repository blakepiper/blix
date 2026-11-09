# Parallel floating Wayland environment for workstation compositions.
{ config, osConfig, lib, pkgs, blixSettings, labwcIconData, labwcExtraBarModules, ... }:
let
  target = "blix-wayland-session.target";
  display = config.blix.display;
  manageOutputs = display.primaryOutput != null;
  outputSettings = pkgs.writeText "blix-wayland-outputs.json" (builtins.toJSON {
    primary = display.primaryOutput;
    external = if config.blix.wayland.externalOutputs != [] then config.blix.wayland.externalOutputs
      else lib.optional (display.externalOutput != null) display.externalOutput
        ++ display.additionalExternalOutputs;
    inherit (display) layout;
    mode = display.mirrorMode;
    rate = display.mirrorRate;
    scales = lib.mapAttrs (_: value: value.scale) config.blix.wayland.outputs;
  });
  outputManager = pkgs.writeShellApplication {
    name = "blix-wayland-outputs";
    runtimeInputs = [ pkgs.python3 pkgs.wlr-randr pkgs.systemd ];
    text = "exec python3 ${../hardware/wayland-outputs.py} ${outputSettings}";
  };
  xml = lib.escapeXML;
  bind = key: action: ''<keybind key="${key}">${action}</keybind>'';
  action = name: ''<action name="${name}" />'';
  execute = command: ''<action name="Execute" command="${xml command}" />'';
  launcher = "${pkgs.fuzzel}/bin/fuzzel";
  lock = "${pkgs.gtklock}/bin/gtklock --daemonize";
  settings = "${blixSettings}/bin/blix-settings";
  panel = pkgs.waybar.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ../../../packaging/waybar/0001-popup-anchor.patch ];
  });
  popupTools = pkgs.writeText "blix-wayland-slider-tools.json" (builtins.toJSON {
    wpctl = "${pkgs.wireplumber}/bin/wpctl";
    brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
    monitorBrightness = config.blix.wayland.brightnessCommand;
    powerMode = "${blixSettings}/bin/blix-settings-apply";
  });
  popup = pkgs.writeShellApplication {
    name = "blix-wayland-slider";
    runtimeInputs = [ pkgs.glib (pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.pycairo ])) ];
    text = ''
      export GI_TYPELIB_PATH="${lib.makeSearchPath "lib/girepository-1.0" (map lib.getLib [ pkgs.gtk3 pkgs.gtk-layer-shell pkgs.glib pkgs.gobject-introspection pkgs.pango pkgs.harfbuzz pkgs.atk pkgs.gdk-pixbuf ])}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
      if [[ ''${1:-} != --daemon ]]; then
        exec gdbus call --session --dest org.blix.BarPopups --object-path /org/blix/BarPopups \
          --method org.blix.BarPopups.Toggle "$1" \
          "$BLIX_PANEL_CENTER" "$BLIX_PANEL_WIDTH" "$BLIX_PANEL_HEIGHT" "$BLIX_PANEL_MONITOR" >/dev/null
      fi
      exec python3 ${../config/labwc/slider.py} ${popupTools} "$@"
    '';
  };
  fileManager = pkgs.thunar.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ../../../packaging/thunar/0001-labwc-wallpaper.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace plugins/thunar-wallpaper/twp-provider.c \
        --replace-fail '@blix-wallpaper@' '${wallpaper}/bin/blix-wayland-wallpaper'
    '';
  });
  appMenu = pkgs.nwg-menu.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ../../../packaging/nwg-menu/0001-consistent-icons.patch ../../../packaging/nwg-menu/0002-resident-menu.patch ];
    # The pinned package omits upstream's category data from its install phase.
    postInstall = (old.postInstall or "") + ''
      cp -r desktop-directories "$out/share/desktop-directories"
    '';
    preFixup = (old.preFixup or "") + ''
      gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share")
    '';
  });
  menu = pkgs.writeShellApplication {
    name = "blix-wayland-menu";
    runtimeInputs = [ appMenu ];
    text = ''
      export XDG_DATA_DIRS="${labwcIconData}/share:${blixSettings}/share:${fileManager}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      exec nwg-menu -resident -ha left -va top -mt 0 -ml 0 -isl 24 -iss 16 -padding 1 -k \
        -fm ${fileManager}/bin/thunar \
        -term ${config.home.sessionVariables.TERMINAL} \
        -cmd-lock '${lock}' \
        -cmd-logout '${pkgs.labwc}/bin/labwc --exit' \
        -cmd-restart '${pkgs.systemd}/bin/systemctl reboot' \
        -cmd-shutdown '${pkgs.systemd}/bin/systemctl poweroff' "$@"
    '';
  };
  controlMenu = pkgs.writeShellApplication {
    name = "blix-wayland-control-menu";
    runtimeInputs = [ pkgs.fuzzel pkgs.systemd pkgs.wlopm pkgs.coreutils ];
    text = ''
      confirm() {
        local answer
        answer=$(printf 'No\nYes\n' | fuzzel --dmenu --prompt "$1 ") || return 1
        [[ $answer == Yes ]]
      }
      choice=$(printf 'Lock\nSuspend\nReboot\nLog Out\nMonitors Off\nPower Off\n' | fuzzel --dmenu --prompt 'Control: ') || exit 0
      case $choice in
        Lock) exec ${lock} ;;
        Suspend) exec ${config.blix.power.suspendCommand} ;;
        Reboot) if confirm 'Reboot?'; then systemctl reboot; fi ;;
        'Log Out') if confirm 'Log out? Unsaved work may be lost.'; then ${pkgs.labwc}/bin/labwc --exit; fi ;;
        'Monitors Off') sleep 0.2; wlopm --off '*' ;;
        'Power Off') if confirm 'Power off?'; then systemctl poweroff; fi ;;
      esac
    '';
  };
  wallpaper = pkgs.writeShellApplication {
    name = "blix-wayland-wallpaper";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/blix/wallpaper"
      if [[ ''${1:-} == --set ]]; then
        [[ $# == 2 && -f $2 && -r $2 ]] || { echo 'Choose a readable image.' >&2; exit 1; }
        mkdir -p "$(dirname "$state")"
        # Keep an owned copy so renaming or removing the source does not reset it.
        temporary=$(mktemp "''${state}.XXXXXX")
        cp -- "$2" "$temporary"
        mv -f -- "$temporary" "$state"
        systemctl --user restart blix-wayland-wallpaper.service
        exit 0
      fi
      image=${lib.escapeShellArg (if config.blix.display.wallpaper == null then "" else config.blix.display.wallpaper)}
      [[ ! -r $state ]] || image=$state
      args=(-c '#1a1b26')
      [[ ! -r $image ]] || args+=(-i "$image" -m fill)
      exec ${pkgs.swaybg}/bin/swaybg "''${args[@]}"
    '';
  };
  ghostty = pkgs.writeShellApplication {
    name = "blix-session-ghostty";
    text = ''
      extra=()
      if [[ ''${XDG_SESSION_TYPE:-} == wayland ]]; then
        extra=(--window-decoration=server --background-opacity=0.85 --background-opacity-cells=true
          --quit-after-last-window-closed=true)
      fi
      exec ${lib.getExe config.programs.ghostty.package} --gtk-single-instance=true --initial-window=false "''${extra[@]}"
    '';
  };
  screenshot = pkgs.writeShellApplication {
    name = "blix-wayland-screenshot";
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard pkgs.coreutils ];
    text = ''
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      file="$directory/$(date +%Y-%m-%d_%H-%M-%S-%N).png"
      if [[ ''${1:-} == --full ]]; then
        grim "$file"
      else
        geometry=$(slurp) || exit 0
        grim -g "$geometry" "$file"
      fi
      wl-copy --type image/png < "$file"
    '';
  };
  clipboard = pkgs.writeShellApplication {
    name = "blix-wayland-clipboard";
    runtimeInputs = [ pkgs.cliphist pkgs.fuzzel pkgs.wl-clipboard ];
    text = ''
      selection=$(cliphist list | fuzzel --dmenu) || exit 0
      [[ -n $selection ]] || exit 0
      printf '%s\n' "$selection" | cliphist decode | wl-copy
    '';
  };
  start = pkgs.writeShellApplication {
    name = "startlabwc";
    runtimeInputs = [ pkgs.systemd pkgs.util-linux pkgs.dbus ];
    text = ''
      if [[ -n ''${DISPLAY:-} || -n ''${WAYLAND_DISPLAY:-} || $(tty) != /dev/tty* ]]; then
        echo 'Run startlabwc from a local text console after exiting your desktop.' >&2
        exit 1
      fi
      if systemctl --user is-active --quiet blix-session.target ${target}; then
        echo 'Exit the existing Blix desktop before starting labwc.' >&2
        exit 1
      fi
      # Serialize launches from multiple TTYs for this user.
      exec 9>"$XDG_RUNTIME_DIR/blix-labwc.lock"
      flock -n 9 || { echo 'labwc is already running.' >&2; exit 1; }
      export XDG_CURRENT_DESKTOP=labwc XDG_SESSION_DESKTOP=labwc XDG_SESSION_TYPE=wayland
      XDG_SESSION_ID=$(loginctl show-session self -p Id --value)
      [[ -n $XDG_SESSION_ID ]] || { echo 'No local logind session found.' >&2; exit 1; }
      export XDG_SESSION_ID
      export MOZ_ENABLE_WAYLAND=1
      original_data_dirs="''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      export XDG_DATA_DIRS="${labwcIconData}/share:$original_data_dirs"
      unset DISPLAY WAYLAND_DISPLAY MOZ_USE_XINPUT2
      cleanup() {
        systemctl --user stop ${target} || true
        systemctl --user stop graphical-session.target || true
        systemctl --user stop xdg-desktop-portal.service xdg-desktop-portal-wlr.service xdg-desktop-portal-gtk.service || true
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY= DISPLAY= XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP= XDG_SESSION_TYPE= XDG_SESSION_ID= MOZ_ENABLE_WAYLAND= XDG_DATA_DIRS="$original_data_dirs" || true
        systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID MOZ_ENABLE_WAYLAND
        systemctl --user set-environment XDG_DATA_DIRS="$original_data_dirs"
      }
      trap cleanup EXIT
      # Keep the lock in this launcher, not in compositor-launched clients.
      ${pkgs.labwc}/bin/labwc "$@" 9>&-
    '';
  };
  autostart = pkgs.writeShellApplication {
    name = "blix-labwc-autostart";
    runtimeInputs = [ pkgs.systemd pkgs.dbus ];
    text = ''
      # labwc now knows its Wayland and Xwayland socket names.
      dbus-update-activation-environment --systemd \
        WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID MOZ_ENABLE_WAYLAND XDG_DATA_DIRS
      systemctl --user stop xdg-desktop-portal.service xdg-desktop-portal-wlr.service xdg-desktop-portal-gtk.service
      systemctl --user start ${target}
    '';
  };
  service = description: command: {
    Unit = { Description = description; PartOf = [ target ]; };
    Service = { ExecStart = command; Restart = "on-failure"; RestartSec = 1; };
  };
in
{
  imports = [ ./labwc-icons.nix ];
  _module.args.labwcExtraBarModules = lib.mkDefault {};
  home.packages = with pkgs; [
    start screenshot clipboard menu controlMenu wallpaper gtklock fuzzel wdisplays wlr-randr wl-clipboard cliphist
    fileManager nwg-look
  ];

  xdg.configFile = {
    "gtklock/config.ini".text = ''
      [main]
      gtk-theme=Adwaita
      layout=${config.xdg.configFile."gtklock/layout.ui".source}
      style=${config.xdg.configFile."gtklock/style.css".source}
    '';
    "gtklock/layout.ui".text = builtins.replaceStrings
      [ "@identity@" ]
      [ (xml "${config.home.username}@${osConfig.networking.hostName}") ]
      (builtins.readFile ../config/labwc/lock.ui);
    "gtklock/style.css".source = ../config/labwc/lock.css;
    "labwc/autostart" = {
      executable = true;
      text = "#!${pkgs.bash}/bin/bash\nexec ${autostart}/bin/blix-labwc-autostart\n";
    };
    "labwc/rc.xml".text = ''
      <?xml version="1.0"?>
      <labwc_config>
        <core><gap>6</gap><decoration>server</decoration></core>
        <placement><policy>cascade</policy></placement>
        <focus><followMouse>no</followMouse></focus>
        <theme>
          <icon>Blix</icon><cornerRadius>0</cornerRadius><font name="JetBrainsMono Nerd Font" size="12" />
          <font place="ActiveWindow" name="JetBrainsMono Nerd Font" size="10" />
          <font place="InactiveWindow" name="JetBrainsMono Nerd Font" size="10" />
          <titlebar><layout>icon:iconify,max,close</layout><showTitle>yes</showTitle></titlebar>
          <maximizedDecoration>titlebar</maximizedDecoration>
        </theme>
        <windowRules><windowRule identifier="*" serverDecoration="yes" /></windowRules>
        <desktops><popupTime>0</popupTime><names>${lib.concatMapStrings (i: "<name>${toString i}</name>") (lib.range 1 9)}</names></desktops>
        <keyboard>
          <repeatRate>50</repeatRate><repeatDelay>200</repeatDelay>
          ${bind "W-Return" (execute config.home.sessionVariables.TERMINAL)}
          ${bind "W-space" (execute launcher)}
          ${bind "W-S-space" (execute "${controlMenu}/bin/blix-wayland-control-menu")}
          ${bind "W-d" (execute launcher)}
          ${bind "W-f" (execute "${fileManager}/bin/thunar")}
          ${bind "W-b" (execute config.home.sessionVariables.BROWSER)}
          ${bind "W-S-b" (execute "${config.home.sessionVariables.BROWSER} --private-window")}
          ${lib.optionalString osConfig.programs.steam.enable
            (bind "W-g" (execute "${osConfig.programs.steam.package}/bin/steam"))}
          ${bind "W-q" (action "Close")}
          ${bind "W-S-q" (action "Exit")}
          ${bind "W-S-f" (action "ToggleMaximize")}
          ${bind "W-m" (action "ToggleMaximize")}
          ${bind "W-p" (action "UnSnap")}
          ${bind "W-Tab" ''<action name="GoToDesktop" to="left" />''}
          ${bind "A-Tab" (action "NextWindow")}
          ${bind "A-S-Tab" (action "PreviousWindow")}
          ${lib.concatMapStringsSep "\n" (i:
            bind "W-${toString i}" ''<action name="GoToDesktop" to="${toString i}" />'' +
            bind "W-S-${toString i}" ''<action name="SendToDesktop" to="${toString i}" follow="no" />''
          ) (lib.range 1 9)}
          ${lib.concatMapStringsSep "\n" (direction:
            bind "W-${direction}" (action (if builtins.elem direction [ "Left" "Up" ] then "PreviousWindowImmediate" else "NextWindowImmediate")) +
            bind "W-S-${direction}" ''<action name="ToggleSnapToEdge" direction="${lib.toLower direction}" />'' +
            bind "W-C-${direction}" ''<action name="FocusOutput" direction="${lib.toLower direction}" wrap="yes" />'' +
            bind "W-C-S-${direction}" ''<action name="MoveToOutput" direction="${lib.toLower direction}" wrap="yes" />''
          ) [ "Left" "Right" "Up" "Down" ]}
          ${bind "W-l" (execute lock)}
          ${bind "W-S-l" (execute config.blix.power.suspendCommand)}
          ${bind "XF86Sleep" (execute config.blix.power.suspendCommand)}
          ${bind "W-s" (execute "${settings}")}
          ${bind "W-v" (execute "${clipboard}/bin/blix-wayland-clipboard")}
          ${bind "W-S-s" (execute "${screenshot}/bin/blix-wayland-screenshot")}
          ${bind "Print" (execute "${screenshot}/bin/blix-wayland-screenshot --full")}
          ${bind "XF86AudioRaiseVolume" (execute "${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")}
          ${bind "XF86AudioLowerVolume" (execute "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")}
          ${bind "XF86AudioMute" (execute "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")}
          ${bind "XF86AudioMicMute" (execute "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")}
          ${bind "XF86AudioPlay" (execute "${pkgs.playerctl}/bin/playerctl play-pause")}
          ${bind "XF86AudioNext" (execute "${pkgs.playerctl}/bin/playerctl next")}
          ${bind "XF86AudioPrev" (execute "${pkgs.playerctl}/bin/playerctl previous")}
          ${lib.optionalString config.blix.hardware.hasBacklight (
            bind "XF86MonBrightnessUp" (execute "${pkgs.brightnessctl}/bin/brightnessctl set +5%") +
            bind "XF86MonBrightnessDown" (execute "${pkgs.brightnessctl}/bin/brightnessctl set 5%-")
          )}
        </keyboard>
        <mouse>
          <default />
          <context name="Root">
            <mousebind button="Left" action="Press"><action name="None" /></mousebind>
            <mousebind button="Middle" action="Press"><action name="None" /></mousebind>
            <mousebind button="Right" action="Press"><action name="None" /></mousebind>
          </context>
          <context name="Frame">
            <mousebind button="W-Left" action="Drag"><action name="Move" /></mousebind>
            <mousebind button="W-Right" action="Drag"><action name="Resize" /></mousebind>
          </context>
        </mouse>
        <libinput>
          <device category="non-touch"><naturalScroll>yes</naturalScroll></device>
          <device category="touchpad">
            <naturalScroll>yes</naturalScroll><tap>yes</tap>
            <tapButtonMap>lrm</tapButtonMap><clickMethod>clickfinger</clickMethod><disableWhileTyping>yes</disableWhileTyping>
          </device>
        </libinput>
      </labwc_config>
    '';
    "labwc/themerc-override".text = ''
      border.width: 2
      # Maximized icon center: 8px padding + 26px / 2 = 21px,
      # matching the panel logo: 10px padding + 22px / 2 = 21px.
      window.titlebar.padding.width: 8
      window.titlebar.padding.height: 1
      window.button.width: 26
      window.button.height: 26
      window.active.border.color: #7aa2f7
      window.inactive.border.color: #414868
      window.active.title.bg.color: #1a1b26
      window.active.label.text.color: #c0caf5
      window.active.button.unpressed.image.color: #c0caf5
      window.inactive.title.bg.color: #1a1b26
      window.inactive.label.text.color: #565f89
      window.inactive.button.unpressed.image.color: #565f89
    '';
    "waybar/config".text = builtins.toJSON ({
      layer = "top";
      position = "top";
      height = 28;
      modules-left = [ "image#logo" "wlr/taskbar" ];
      modules-right = lib.optional config.blix.hardware.hasBattery "battery"
        ++ [ "pulseaudio" ]
        ++ lib.optional (config.blix.wayland.brightnessCommand != null) "custom/brightness"
        ++ lib.optional config.blix.hardware.hasBacklight "backlight"
        ++ [ "memory" "cpu_usage" ]
        ++ builtins.attrNames labwcExtraBarModules ++ [ "clock" ];
      "image#logo" = {
        path = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        size = 22;
        # This Waybar version otherwise reloads a static image every millisecond.
        interval = "once";
        tooltip-format = "Applications, settings and session";
        on-click = "${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main --signal=USR1 blix-wayland-menu.service";
      };
      "wlr/taskbar" = {
        format = "{icon} {title:.24}";
        icon-size = 18;
        icon-theme = "Blix";
        # Keep minimized windows reachable even when their output changes.
        all-outputs = true;
        tooltip-format = "{title}";
        on-click = "minimize-raise";
      };
      clock = { format = "{:%H:%M}"; interval = 60; };
      # This native module reads /proc/stat only. The generic cpu module also
      # queries frequency on every core even when its format never displays it.
      cpu_usage = { format = "CPU: {usage}%"; interval = 10; };
      memory = { format = "Ram: {used:0.1f}/{total:0.1f}"; interval = 30; };
      battery = {
        format = "Bat: {capacity}%";
        format-discharging = "Bat: {capacity}% {time}";
        format-time = "{H}h{M}m";
        format-charging = "Bat: {capacity}% +";
        format-plugged = "Bat: {capacity}% +";
        format-full = "Bat: {capacity}% +";
        format-not-charging = "Bat: {capacity}% +";
        # Kernel events update charging/capacity immediately. This is only a
        # fallback rescan, not the normal update path.
        interval = 60;
        tooltip-format-charging = "Charging · {capacity}%\n{timeTo}";
      } // lib.optionalAttrs config.blix.hardware.hasPowerProfiles {
        on-click = "${popup}/bin/blix-wayland-slider power";
        blix-popup-anchor = true;
      };
      pulseaudio = {
        format = "Vol {volume}%"; format-muted = "Vol muted";
        on-click = "${popup}/bin/blix-wayland-slider volume";
        blix-popup-anchor = true;
        on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };
      "custom/brightness" = {
        exec = config.blix.wayland.brightnessCommand;
        format = "Bri {}";
        # Only reads the worker's cached file; never polls DDC/CI.
        interval = 1;
        tooltip = false;
        on-click = "${popup}/bin/blix-wayland-slider monitor-brightness";
        blix-popup-anchor = true;
      };
      backlight = {
        format = "Bri {percent}%";
        # Udev supplies changes; avoid re-enumerating devices every two seconds.
        interval = 60;
        on-click = "${popup}/bin/blix-wayland-slider brightness";
        blix-popup-anchor = true;
        on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set +5%";
        on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl --class=backlight --min-value=1 set 5%-";
      };
    } // labwcExtraBarModules);
    "waybar/style.css".text = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 10pt;
        min-height: 0;
        border: none;
        border-radius: 0;
      }
      window#waybar { background: #1a1b26; color: #bbbbbb; }
      #image.logo { padding: 0 10px; }
      #image.logo:hover, #pulseaudio:hover, #backlight:hover, #custom-brightness:hover, #battery:hover { background: #34324a; }
      #taskbar { margin-left: 8px; }
      #taskbar button {
        background: transparent;
        padding: 0 8px;
        box-shadow: none;
      }
      #taskbar button.active { box-shadow: inset 0 -2px #d7ffe8; }
      #taskbar button.minimized {
        background: #292e42;
        box-shadow: inset 0 -2px #e0af68;
      }
      #taskbar button:hover { background: #34324a; }
      #clock, #cpu_usage, #memory, #battery, #pulseaudio, #backlight, #custom-brightness, #custom-gpu, #tray {
        padding: 0 10px;
        margin: 3px 0;
        border-left: 1px solid #6e738d;
      }
      .modules-right > widget:first-child > * { border-left: none; }
      #battery, #custom-gpu { color: #a6da95; }
      #pulseaudio { color: #8aadf4; }
      #backlight, #custom-brightness { color: #eed49f; }
      #memory { color: #c6a0f6; }
      #cpu_usage { color: #ed8796; }
      #clock { color: #cad3f5; }
    '';
    "fuzzel/fuzzel.ini".text = ''
      [main]
      icon-theme=Blix
      font=JetBrainsMono Nerd Font:size=12
      prompt="Apps: "
      width=48
      lines=12
      [colors]
      background=1a1b26ff
      text=c0caf5ff
      match=7dcfffff
      selection=292e42ff
      selection-text=c0caf5ff
      selection-match=7aa2f7ff
      border=7aa2f7ff
      [border]
      width=2
      radius=0
    '';
    "nwg-panel/menu-start.css".text = ''
      * { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; color: #c0caf5; }
      window { background: #1a1b26; color: #c0caf5; border: 1px solid #292e42; }
      list, row { background: transparent; }
      row { padding: 4px 6px; }
      row:hover { background: #292e42; }
      #outer-box { padding: 12px; }
      button { background-image: none; background: transparent; color: #c0caf5; border: none; box-shadow: none; min-width: 26px; min-height: 26px; padding: 6px; }
      button:hover { background: #292e42; }
      entry { background: #16161e; color: #c0caf5; padding: 9px; border: 1px solid #414868; border-radius: 6px; }
    '';
    # The same terminal instance belongs to whichever desktop is running.
    "systemd/user/app-com.mitchellh.ghostty.service.d/wayland-session.conf".text = ''
      [Unit]
      PartOf=${target}
      [Service]
      ExecStart=
      ExecStart=${ghostty}/bin/blix-session-ghostty
    '';
  };

  systemd.user.targets.blix-wayland-session.Unit = {
    Description = "Blix labwc Wayland session services";
    BindsTo = [ "graphical-session.target" ];
    After = [ "graphical-session.target" ];
    Wants = [ "dunst.service"
      "blix-wayland-polkit.service"
      "blix-wayland-panel.service" "blix-wayland-menu.service" "blix-wayland-sliders.service" "blix-wayland-lock.service"
      "blix-wayland-clipboard.service" "blix-wayland-wallpaper.service"
      "blix-wayland-nightlight.service" ]
      ++ lib.optional config.services.blueman-applet.enable "blueman-applet.service"
      ++ lib.optional (manageOutputs || config.blix.wayland.outputs != {}) "blix-wayland-outputs.service";
  };
  systemd.user.services = {
    blix-wayland-polkit = service "Graphical authorization for the Wayland session"
      "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    blueman-applet = lib.mkIf config.services.blueman-applet.enable {
      Unit.PartOf = [ target ];
    };
    blix-wayland-menu = lib.recursiveUpdate
      (service "Warm Wayland application menu" "${menu}/bin/blix-wayland-menu")
      { Install.WantedBy = [ target ]; Unit.X-Restart-Triggers = [ "${config.home.path}" ]; };
    blix-wayland-sliders = lib.recursiveUpdate
      (service "Warm Wayland panel controls" "${popup}/bin/blix-wayland-slider --daemon")
      {
        Install.WantedBy = [ target ];
        Service = { Type = "dbus"; BusName = "org.blix.BarPopups"; };
      };
    blix-wayland-panel = lib.recursiveUpdate
      (service "Blix Wayland panel" "${panel}/bin/waybar")
      {
        Unit.After = [ "blix-wayland-menu.service" "blix-wayland-sliders.service" ];
        Unit.X-Restart-Triggers = [
          config.xdg.configFile."waybar/config".source
          config.xdg.configFile."waybar/style.css".source
        ];
      };
    blix-wayland-outputs = lib.mkIf (manageOutputs || config.blix.wayland.outputs != {}) {
      Install.WantedBy = [ target ];
      Unit = { Description = "Blix Wayland display layout and scaling"; PartOf = [ target ]; };
      Service = if manageOutputs then {
        ExecStart = "${outputManager}/bin/blix-wayland-outputs";
        Restart = "on-failure";
        RestartSec = 2;
      } else {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = map (name:
          "${pkgs.wlr-randr}/bin/wlr-randr --output ${name} --scale ${toString config.blix.wayland.outputs.${name}.scale}"
        ) (builtins.attrNames config.blix.wayland.outputs);
      };
    };
    blix-wayland-lock = service "Lock Wayland on suspend and logind lock requests"
      "${pkgs.swayidle}/bin/swayidle -w before-sleep '${lock}' lock '${lock}'";
    blix-wayland-nightlight = {
      Unit = {
        Description = "Blix Wayland night light";
        PartOf = [ target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        Type = "exec";
        ExecStart = "${blixSettings}/bin/blix-settings-apply nightlight";
        # Disconnecting restores the original gamma tables on Wayland. A separate
        # reset client stays alive holding gamma control and delays later starts.
      };
    };
    blix-wayland-clipboard = service "Wayland text clipboard history"
      "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
    blix-wayland-wallpaper = service "Blix Wayland wallpaper"
      "${wallpaper}/bin/blix-wayland-wallpaper";
  };
}
