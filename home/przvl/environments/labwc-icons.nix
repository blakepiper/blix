# One Firefox asset for the compositor, launchers, toolkit fallback and notices.
{ config, lib, pkgs, ... }:
let
  firefox = ../config/labwc/icons/firefox.svg;
  names = [ "firefox" "firefox-esr" "org.mozilla.firefox" ];
  iconData = pkgs.runCommand "blix-wayland-icons" {
    nativeBuildInputs = [ pkgs.librsvg pkgs.desktop-file-utils ];
  } ''
    mkdir -p "$out/share/icons/hicolor/scalable/apps" "$out/share/icons/Blix/scalable/apps" "$out/share/applications"
    cp ${pkgs.hicolor-icon-theme}/share/icons/hicolor/index.theme "$out/share/icons/hicolor/"
    cat > "$out/share/icons/Blix/index.theme" <<'EOF'
    [Icon Theme]
    Name=Blix
    Inherits=Adwaita,hicolor
    Directories=scalable/apps
    [scalable/apps]
    Size=48
    Type=Scalable
    MinSize=16
    MaxSize=512
    Context=Applications
    EOF
    for name in ${lib.escapeShellArgs names}; do
      ln -s ${firefox} "$out/share/icons/hicolor/scalable/apps/$name.svg"
      ln -s ${firefox} "$out/share/icons/Blix/scalable/apps/$name.svg"
    done
    # Exact-size fallbacks also cover GTK/Qt applications using Adwaita. Build
    # them once, rather than converting the vector each time a menu opens.
    for size in 16 22 24 32 48 64 96 128 256 512; do
      directory="$out/share/icons/hicolor/''${size}x''${size}/apps"
      mkdir -p "$directory"
      rsvg-convert -w "$size" -h "$size" ${firefox} > "$directory/firefox.png"
      for name in firefox-esr org.mozilla.firefox; do
        ln -s firefox.png "$directory/$name.png"
      done
    done
    # Absolute icons bypass launcher-specific theme choices and cached aliases.
    sed -e 's|^Icon=.*|Icon=${firefox}|' \
      -e 's|^Exec=firefox|Exec=${lib.getExe config.programs.firefox.finalPackage}|' \
      ${config.programs.firefox.finalPackage}/share/applications/firefox.desktop \
      > "$out/share/applications/firefox.desktop"
    desktop-file-validate "$out/share/applications/firefox.desktop"
  '';
  notifications = pkgs.runCommand "blix-wayland-dunstrc" {} ''
    cat ${config.xdg.configFile."dunst/dunstrc".source} > "$out"
    cat >> "$out" <<'EOF'

    [blix-firefox]
    appname=*[Ff]irefox*
    new_icon=${firefox}
    EOF
  '';
  dunst = pkgs.writeShellApplication {
    name = "blix-session-dunst";
    text = ''
      if [[ ''${XDG_SESSION_TYPE:-} == wayland ]]; then
        exec ${pkgs.dunst}/bin/dunst --config ${notifications} "$@"
      fi
      exec ${pkgs.dunst}/bin/dunst "$@"
    '';
  };
in
{
  _module.args.labwcIconData = iconData;
  systemd.user.services.dunst.Service.ExecStart = lib.mkForce "${dunst}/bin/blix-session-dunst";
  # Kept outside the global applications/icons directories; only the Wayland
  # environment adds these assets to its search path.
  xdg.dataFile."blix/wayland".source = "${iconData}/share";
}
