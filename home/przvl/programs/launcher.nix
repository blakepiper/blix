{ config, ... }:

{
  programs.fuzzel = {
    enable = true;
    # The included file carries its own [colors] section; see themes/apps.nix.
    settings.main.include = "${config.blix.currentThemeDir}/fuzzel.ini";
  };
}
