{ ... }:

{
  programs.btop = {
    enable = true;

    # This stable theme name resolves through ~/.config/btop/themes/blix.theme,
    # which follows ~/.config/blix/current as the workstation theme changes.
    settings.color_theme = "blix";
  };
}
