{ pkgs, ... }:

{
  home.pointerCursor = {
    enable = true;
    package = pkgs.whitesur-cursors;
    name = "WhiteSur-cursors";
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk.enable = true;
}
