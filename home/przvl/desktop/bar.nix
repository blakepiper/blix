{ resources, ... }:

let
  iconDir = ".local/share/wayle/icons/hicolor/scalable/actions";

  # Wayle owns this directory: on startup it compiles each icon it finds there
  # into its own drawing format, replacing the link Home Manager planted. Home
  # Manager would then refuse to relink the file it no longer recognises and
  # fail activation, so every rebuild from a running Wayle session needs these
  # to overwrite. Wayle recompiles them when the theme activation restarts it.
  wayleIcon = source: {
    inherit source;
    force = true;
  };
in
{
  home.file."${iconDir}/cm-ai-usage-symbolic.svg" = wayleIcon resources.icons.aiUsage;
  home.file."${iconDir}/cm-theme-symbolic.svg" = wayleIcon resources.icons.theme;
  home.file."${iconDir}/ld-sun-symbolic.svg" = wayleIcon resources.icons.night.off;
  home.file."${iconDir}/ld-moon-symbolic.svg" = wayleIcon resources.icons.night.on;
  home.file."${iconDir}/ld-eclipse-symbolic.svg" = wayleIcon resources.icons.night.plus;

  # The bar's layout, modules, and palette are all part of a theme, so
  # config.toml is supplied by the active theme rather than by this module.
  # See themes/apps.nix.
  services.wayle.enable = true;

  # Stop the previous notification daemon before Wayle claims the notification bus.
  systemd.user.services.wayle.Unit.Conflicts = [ "mako.service" ];
}
