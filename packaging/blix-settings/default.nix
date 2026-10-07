{ lib, stdenvNoCC, python3, gtk3, gobject-introspection, wrapGAppsHook3
, networkmanager, networkmanagerapplet, pulseaudio, xrandr, xinput, xset
, brightnessctl, systemd, adwaita-icon-theme }:

let
  python = python3.withPackages (ps: [ ps.pygobject3 ps.pycairo ps.dbus-python ]);
  tools = {
    xrandr = "${xrandr}/bin/xrandr";
    xinput = "${xinput}/bin/xinput";
    xset = "${xset}/bin/xset";
    pactl = "${pulseaudio}/bin/pactl";
    paplay = "${pulseaudio}/bin/paplay";
    parec = "${pulseaudio}/bin/parec";
    brightnessctl = "${brightnessctl}/bin/brightnessctl";
    systemctl = "${systemd}/bin/systemctl";
    udevadm = "${systemd}/bin/udevadm";
    connectionEditor = "${networkmanagerapplet}/bin/nm-connection-editor";
  };
in
stdenvNoCC.mkDerivation {
  pname = "blix-settings";
  version = "0.1.0";
  src = ./src;
  nativeBuildInputs = [ wrapGAppsHook3 gobject-introspection ];
  buildInputs = [ gtk3 networkmanager adwaita-icon-theme ];
  preFixup = ''
    gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : ${adwaita-icon-theme}/share)
  '';
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/blix-settings" "$out/share/applications"
    cp *.py *.css "$out/share/blix-settings/"
    cp ${../../home/przvl/config/oxwm/config.lua} "$out/share/blix-settings/shortcuts.lua"
    cat > "$out/share/blix-settings/tools.json" <<'EOF'
    ${builtins.toJSON tools}
    EOF
    for entry in blix-settings blix-settings-apply; do
      cat > "$out/bin/$entry" <<EOF
    #!${python}/bin/python3
    import sys
    sys.path.insert(0, "$out/share/blix-settings")
    from main import main
    main(gui="$entry" == "blix-settings")
    EOF
      chmod +x "$out/bin/$entry"
    done
    ${python}/bin/python3 - "$out/share/blix-settings/test.wav" <<'PY'
    import math, struct, sys, wave
    with wave.open(sys.argv[1], 'wb') as sound:
        sound.setparams((1, 2, 24000, 0, 'NONE', 'not compressed'))
        sound.writeframes(b"".join(struct.pack('<h', int(4500 * math.sin(2 * math.pi * 440 * i / 24000)
            * min(1, i / 1200, (12000 - i) / 1200))) for i in range(12000)))
    PY
    cat > "$out/share/applications/org.blix.Settings.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=Blix Settings
    Comment=Display, audio, Bluetooth, network, power and input controls
    Exec=$out/bin/blix-settings
    Icon=preferences-system
    Categories=Settings;System;
    StartupNotify=true
    EOF
    runHook postInstall
  '';
  meta = {
    description = "Native settings for the Blix X11 desktop";
    mainProgram = "blix-settings";
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}
