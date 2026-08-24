{ theme, ... }:

{
  programs.alacritty = {
    enable = true;
    settings.colors = {
      primary = {
        background = theme.colors.background;
        foreground = theme.colors.foreground;
      };
      normal = {
        black = theme.colors.background;
        red = theme.colors.red;
        green = theme.colors.green;
        yellow = theme.colors.yellow;
        blue = theme.colors.blue;
        magenta = theme.colors.magenta;
        cyan = theme.colors.cyan;
        white = theme.colors.white;
      };
      bright = {
        black = theme.colors.brightBlack;
        red = theme.colors.brightRed;
        green = theme.colors.brightGreen;
        yellow = theme.colors.brightYellow;
        blue = theme.colors.brightBlue;
        magenta = theme.colors.brightMagenta;
        cyan = theme.colors.brightCyan;
        white = theme.colors.brightWhite;
      };
      cursor = {
        text = theme.colors.background;
        cursor = theme.colors.foreground;
      };
    };
  };
}
