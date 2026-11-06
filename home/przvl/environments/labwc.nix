# Parallel floating Wayland environment for workstation compositions.
{ config, lib, pkgs, ... }:
let
  target = "blix-wayland-session.target";
  xml = lib.escapeXML;
  bind = key: action: ''<keybind key="${key}">${action}</keybind>'';
  action = name: ''<action name="${name}" />'';
  execute = command: ''<action name="Execute" command="${xml command}" />'';
  launcher = "${pkgs.fuzzel}/bin/fuzzel";
  lock = "${pkgs.swaylock}/bin/swaylock -f -c 1a1b26";
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
      export MOZ_ENABLE_WAYLAND=1
      unset DISPLAY WAYLAND_DISPLAY MOZ_USE_XINPUT2
      cleanup() {
        systemctl --user stop ${target} || true
        systemctl --user stop xdg-desktop-portal.service xdg-desktop-portal-wlr.service xdg-desktop-portal-gtk.service || true
        dbus-update-activation-environment --systemd WAYLAND_DISPLAY= DISPLAY= XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP= XDG_SESSION_TYPE= MOZ_ENABLE_WAYLAND= || true
        systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE MOZ_ENABLE_WAYLAND
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
        WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE MOZ_ENABLE_WAYLAND
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
  home.packages = with pkgs; [
    start screenshot clipboard fuzzel wdisplays wlr-randr wl-clipboard cliphist
  ];

  xdg.configFile = {
    "labwc/autostart" = {
      executable = true;
      text = "#!${pkgs.bash}/bin/bash\nexec ${autostart}/bin/blix-labwc-autostart\n";
    };
    "labwc/rc.xml".text = ''
      <?xml version="1.0"?>
      <labwc_config>
        <core><gap>6</gap></core>
        <placement><policy>cascade</policy></placement>
        <focus><followMouse>no</followMouse></focus>
        <theme><cornerRadius>0</cornerRadius><font name="JetBrainsMono Nerd Font" size="12" /></theme>
        <desktops><number>9</number></desktops>
        <keyboard>
          <repeatRate>50</repeatRate><repeatDelay>200</repeatDelay>
          ${bind "W-Return" (execute config.home.sessionVariables.TERMINAL)}
          ${bind "W-space" (execute launcher)}
          ${bind "W-d" (execute launcher)}
          ${bind "W-f" (execute "${pkgs.xfe}/bin/xfe")}
          ${bind "W-b" (execute config.home.sessionVariables.BROWSER)}
          ${bind "W-q" (action "Close")}
          ${bind "W-S-q" (action "Exit")}
          ${bind "W-S-f" (action "ToggleFullscreen")}
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
          ${bind "W-s" (execute "${pkgs.wdisplays}/bin/wdisplays")}
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
          <context name="Frame">
            <mousebind button="W-Left" action="Drag"><action name="Move" /></mousebind>
            <mousebind button="W-Right" action="Drag"><action name="Resize" /></mousebind>
          </context>
        </mouse>
        <libinput>
          <device category="touchpad">
            <naturalScroll>yes</naturalScroll><tap>yes</tap>
            <tapButtonMap>lrm</tapButtonMap><clickMethod>clickfinger</clickMethod><disableWhileTyping>yes</disableWhileTyping>
          </device>
        </libinput>
      </labwc_config>
    '';
    "labwc/themerc".text = ''
      border.width: 2
      window.active.border.color: #98c379
      window.inactive.border.color: #444444
      window.active.title.bg.color: #1a1b26
      window.active.label.text.color: #bbbbbb
      window.inactive.title.bg.color: #1a1b26
      window.inactive.label.text.color: #777777
    '';
    "waybar/config".text = builtins.toJSON {
      layer = "top";
      position = "top";
      height = 28;
      modules-left = [ "wlr/taskbar" ];
      modules-right = [ "pulseaudio" "cpu" "memory" ]
        ++ lib.optional config.blix.hardware.hasBattery "battery" ++ [ "clock" "tray" ];
      "wlr/taskbar" = { format = "{title}"; "on-click" = "activate"; "on-click-middle" = "close"; };
      clock.format = "{:%a %b %d  %H:%M}";
      cpu.format = "CPU {usage}%";
      memory.format = "RAM {percentage}%";
      battery.format = "BAT {capacity}%";
      pulseaudio.format = "VOL {volume}%";
    };
    "waybar/style.css".text = ''
      * { font-family: "JetBrainsMono Nerd Font"; font-size: 13px; }
      window#waybar { background: #1a1b26; color: #bbbbbb; }
      #clock, #cpu, #memory, #battery, #pulseaudio, #tray { padding: 0 10px; }
      #taskbar button { color: #bbbbbb; border-radius: 0; }
      #taskbar button.active { border-bottom: 2px solid #98c379; }
    '';
    # The same terminal instance belongs to whichever desktop is running.
    "systemd/user/app-com.mitchellh.ghostty.service.d/wayland-session.conf".text = ''
      [Unit]
      PartOf=${target}
    '';
  };

  systemd.user.targets.blix-wayland-session.Unit = {
    Description = "Blix labwc Wayland session services";
    Wants = [ "dunst.service" "app-com.mitchellh.ghostty.service"
      "blix-wayland-panel.service" "blix-wayland-lock.service"
      "blix-wayland-clipboard.service" "blix-wayland-wallpaper.service" ]
      ++ lib.optional config.services.blueman-applet.enable "blueman-applet.service";
  };
  systemd.user.services = {
    blueman-applet = lib.mkIf config.services.blueman-applet.enable {
      Unit.PartOf = [ target ];
    };
    blix-wayland-panel = service "Blix Wayland panel" "${pkgs.waybar}/bin/waybar";
    blix-wayland-lock = service "Lock Wayland on suspend and logind lock requests"
      "${pkgs.swayidle}/bin/swayidle -w before-sleep '${lock}' lock '${lock}'";
    blix-wayland-clipboard = service "Wayland text clipboard history"
      "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
    blix-wayland-wallpaper = service "Blix Wayland wallpaper"
      ("${pkgs.swaybg}/bin/swaybg -c '#1a1b26'" + lib.optionalString (config.blix.display.wallpaper != null)
        " -i ${lib.escapeShellArg config.blix.display.wallpaper} -m fill");
  };
}
