{ config, pkgs, theme, ... }:

{
  home.pointerCursor = {
    enable = true;
    package = pkgs.whitesur-cursors;
    name = theme.cursor.name;
    size = theme.cursor.size;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    # Both toolkits read the same generated color definitions. The GTK color
    # scheme itself is set at runtime by blix-theme, since it changes without
    # a rebuild.
    gtk3.extraCss = ''
      @import url("file://${config.blix.currentThemeDir}/gtk.css");
    '';
    gtk4.extraCss = ''
      @import url("file://${config.blix.currentThemeDir}/gtk.css");
    '';
  };
}
