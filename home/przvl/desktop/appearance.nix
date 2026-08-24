{ pkgs, theme, ... }:

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
    colorScheme = "light";
    gtk3.extraCss = ''
      @define-color theme_bg_color ${theme.colors.background};
      @define-color theme_fg_color ${theme.colors.foreground};
      @define-color theme_selected_bg_color ${theme.colors.primary};
      @define-color theme_selected_fg_color ${theme.colors.background};
      @define-color borders alpha(${theme.colors.foreground}, 0.15);
      selection { background-color: ${theme.colors.primary}; color: ${theme.colors.background}; }
    '';
    gtk4.extraCss = ''
      @define-color window_bg_color ${theme.colors.background};
      @define-color window_fg_color ${theme.colors.foreground};
      @define-color accent_bg_color ${theme.colors.primary};
      @define-color accent_fg_color ${theme.colors.background};
      @define-color borders alpha(${theme.colors.foreground}, 0.15);
      selection { background-color: ${theme.colors.primary}; color: ${theme.colors.background}; }
    '';
  };
}
