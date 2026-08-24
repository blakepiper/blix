{ theme, ... }:

{
  programs.fuzzel = {
    enable = true;
    settings.colors = {
      background = "${theme.colors.background}ff";
      text = "${theme.colors.foreground}ff";
      match = "${theme.colors.primary}ff";
      selection = "${theme.colors.primary}ff";
      selection-text = "${theme.colors.background}ff";
      selection-match = "${theme.colors.background}ff";
      border = "${theme.colors.border}ff";
    };
  };
}
