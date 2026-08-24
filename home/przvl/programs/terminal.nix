{ config, ... }:

{
  programs.alacritty = {
    enable = true;
    # Colors come from the active theme. Alacritty applies imports first, so
    # anything set here still wins.
    settings.general.import = [ "${config.blix.currentThemeDir}/alacritty.toml" ];
  };
}
