{ lib, ghostty, makeWrapper, symlinkJoin, xdg-utils, browser }:

symlinkJoin {
  name = "ghostty-${ghostty.version}-blix";
  inherit (ghostty) version meta;
  paths = [ ghostty ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    rm "$out/bin/ghostty"
    makeWrapper ${lib.getExe ghostty} "$out/bin/ghostty" \
      --set BROWSER ${lib.getExe browser} \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}

    # D-Bus/systemd activation must launch the same corrected terminal.
    for file in share/dbus-1/services/com.mitchellh.ghostty.service \
      share/systemd/user/app-com.mitchellh.ghostty.service; do
      cp --remove-destination "${ghostty}/$file" "$out/$file"
      chmod u+w "$out/$file"
      substituteInPlace "$out/$file" \
        --replace-fail "${lib.getExe ghostty}" "$out/bin/ghostty"
    done
  '';
  passthru = (ghostty.passthru or { }) // {
    inherit (ghostty) man terminfo vim;
  };
}
