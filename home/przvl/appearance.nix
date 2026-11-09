{ config, lib, pkgs, ... }:

let
  tokyoGtk = pkgs.tokyonight-gtk-theme.override {
    colorVariants = [ "dark" ];
    sizeVariants = [ "standard" ];
    themeVariants = [ "default" ];
  };
  qtColors = [
    "#c0caf5" "#24283b" "#414868" "#292e42" "#15161e" "#3b4261"
    "#c0caf5" "#f7768e" "#c0caf5" "#16161e" "#1a1b26" "#15161e"
    "#7aa2f7" "#1a1b26" "#7dcfff" "#bb9af7" "#1f2335" "#1a1b26"
    "#24283b" "#c0caf5" "#565f89"
  ];
  qtPalette = version: pkgs.writeText "tokyonight-qt${toString version}.conf" ''
    [ColorScheme]
    active_colors=${lib.concatStringsSep ", " (qtColors ++ lib.optional (version == 6) "#7aa2f7")}
    inactive_colors=${lib.concatStringsSep ", " (qtColors ++ lib.optional (version == 6) "#7aa2f7")}
    disabled_colors=${lib.concatStringsSep ", " (map (color: if color == "#c0caf5" then "#565f89" else color) qtColors ++ lib.optional (version == 6) "#565f89")}
  '';
  qtSettings = version: {
    Appearance = {
      style = "Fusion";
      custom_palette = true;
      color_scheme_path = toString (qtPalette version);
      icon_theme = "Adwaita";
    };
    Fonts = {
      general = ''"JetBrainsMono Nerd Font,10"'';
      fixed = ''"JetBrainsMono Nerd Font,10"'';
    };
  };
in
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
  gtk.font = { name = "JetBrainsMono Nerd Font"; size = 10; };
  gtk.theme = { name = "Tokyonight-Dark"; package = tokyoGtk; };
  gtk.gtk4.theme = config.gtk.theme;
  gtk.colorScheme = "dark";
  gtk.iconTheme = { name = "Adwaita"; package = pkgs.adwaita-icon-theme; };
  # Also expose the named theme to applications before a profile/session restart.
  xdg.dataFile."themes/Tokyonight-Dark".source = "${tokyoGtk}/share/themes/Tokyonight-Dark";
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Tokyonight-Dark";
    font-name = "JetBrainsMono Nerd Font 10";
    icon-theme = "Adwaita";
  };
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "Fusion";
    qt5ctSettings = qtSettings 5;
    qt6ctSettings = qtSettings 6;
  };
  gtk.gtk3.extraConfig = lib.optionalAttrs (config.blix.display.dpi != null) {
    gtk-xft-dpi = config.blix.display.dpi * 1024;
  };
}
