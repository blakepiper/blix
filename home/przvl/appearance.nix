{ config, lib, pkgs, ... }:

let
  xfeTheme = pkgs.writeShellApplication {
    name = "blix-xfe-theme";
    runtimeInputs = [ pkgs.coreutils pkgs.crudini ];
    text = ''
      config_file="$1"
      if [[ ! -e "$config_file" ]]; then
        install -Dm600 ${pkgs.xfe}/share/xfe/xferc "$config_file"
      fi
      crudini --merge "$config_file" < ${./config/xfe/xferc}
    '';
  };
in
{
  # Merge only theme colors into Xfe's writable preferences. On first use,
  # retain the packaged keybindings and file associations as well.
  home.activation.xfeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${xfeTheme}/bin/blix-xfe-theme ${lib.escapeShellArg "${config.xdg.configHome}/xfe/xferc"}
  '';

  home.pointerCursor = {
    enable = true;
    package = pkgs.whitesur-cursors;
    name = "WhiteSur-cursors";
    size = lib.mkDefault 32;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk.enable = true;
  gtk.gtk3.extraConfig = lib.optionalAttrs (config.blix.display.dpi != null) {
    gtk-xft-dpi = config.blix.display.dpi * 1024;
  };
}
