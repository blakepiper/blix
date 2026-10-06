{ config, lib, pkgs, ... }:

{
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
