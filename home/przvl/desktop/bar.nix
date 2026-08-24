{ resources, ... }:

let
  iconDir = ".local/share/wayle/icons/hicolor/scalable/actions";
in
{
  home.file."${iconDir}/cm-ai-usage-symbolic.svg".source = resources.icons.aiUsage;
  home.file."${iconDir}/cm-theme-symbolic.svg".source = resources.icons.theme;
  home.file."${iconDir}/ld-sun-symbolic.svg".source = resources.icons.night.off;
  home.file."${iconDir}/ld-moon-symbolic.svg".source = resources.icons.night.on;
  home.file."${iconDir}/ld-eclipse-symbolic.svg".source = resources.icons.night.plus;

  # The bar's layout, modules, and palette are all part of a theme, so
  # config.toml is supplied by the active theme rather than by this module.
  # See themes/apps.nix.
  services.wayle.enable = true;

  # Stop the previous notification daemon before Wayle claims the notification bus.
  systemd.user.services.wayle.Unit.Conflicts = [ "mako.service" ];
}
