# The Blix theme system.
#
# Every theme is a palette (themes/<name>.nix). apps.nix turns a palette into a
# directory of per-application configuration files, and all of those
# directories are installed to ~/.config/blix/themes. ~/.config/blix/current is
# a symlink into one of them, and is the only mutable piece: switching themes
# re-points it and nudges the running session, with no rebuild.
#
# Applications reach the active theme in one of two ways:
#
#   * those that can include a fragment (alacritty, fuzzel, GTK, btop, neovim)
#     keep their home-manager configuration and point at ~/.config/blix/current
#   * those that cannot (wayle, hyprlock) have their whole config file
#     symlinked into ~/.config/blix/current instead
{ config, lib, pkgs, theme, nightMode, aiUsage, ... }:

let
  palettes = {
    blix = import ./blix.nix;
    archriot = import ./archriot.nix;
  };

  defaultTheme = "blix";

  configDir = "${config.xdg.configHome}/blix";
  currentDir = "${configDir}/current";

  script = pkgs.writeShellApplication {
    name = "blix-theme";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      glib
      hyprland
      systemd
    ];
    text = ''
      DEFAULT_THEME=${lib.escapeShellArg defaultTheme}
      # gsettings finds no schemas under a bare systemd user environment.
      export XDG_DATA_DIRS=${
        lib.escapeShellArg "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
      }"''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    ''
    + builtins.readFile ./blix-theme.sh;
  };

  mkThemeFiles = import ./apps.nix {
    inherit (theme) font;
    inherit pkgs lib nightMode aiUsage;
    isLaptop = config.blix.formFactor == "laptop";
    blixTheme = script;
  };

  themesDir = pkgs.runCommand "blix-themes" { } (
    lib.concatStrings (
      lib.mapAttrsToList (
        name: palette:
        let
          files = mkThemeFiles palette;
        in
        ''
          mkdir -p $out/${name}
        ''
        + lib.concatStrings (
          lib.mapAttrsToList (file: source: ''
            cp ${source} $out/${name}/${file}
          '') files
        )
      ) palettes
    )
  );
in
{
  options.blix.currentThemeDir = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = currentDir;
    description = ''
      Directory holding the active theme's per-application configuration
      files. Modules that include a theme fragment point at this path.
    '';
  };

  config.assertions = [
    {
      assertion = palettes ? ${defaultTheme};
      message = "themes: default theme '${defaultTheme}' has no palette";
    }
  ];

  config.home.packages = [ script ];

  config.xdg.configFile."blix/themes".source = themesDir;

  # Wayle, hyprlock, and hyprpaper have no include directive, so the active
  # theme supplies their configuration file wholesale.
  config.xdg.configFile."wayle/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${currentDir}/wayle.toml";
  config.xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${currentDir}/hyprlock.conf";
  config.xdg.configFile."hypr/hyprpaper.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${currentDir}/hyprpaper.conf";

  # btop rewrites btop.conf itself, so that file stays btop's. Exposing the
  # theme under its themes directory instead lets btop pick it by name, and the
  # symlink means it then follows whatever theme is active.
  config.xdg.configFile."btop/themes/blix.theme".source =
    config.lib.file.mkOutOfStoreSymlink "${currentDir}/btop.theme";

  # A fresh machine has no ~/.config/blix/current yet, and wayle would start
  # without a configuration file. Create it during activation, before the
  # session starts.
  # linkGeneration is what creates ~/.config/blix/themes, so this has to run
  # after it, not merely after writeBoundary.
  config.home.activation.blixTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${script}/bin/blix-theme ensure || true
  '';

  # Wayle's config.toml is a symlink to the active theme, so home-manager never
  # sees its contents change and will not restart the bar on its own.
  # try-restart is a no-op when the bar is not running, such as at boot.
  config.home.activation.blixThemeBar = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    run ${pkgs.systemd}/bin/systemctl --user try-restart wayle.service || true
  '';

  # Border colors and the GTK color scheme are set by command, so they have to
  # be re-applied for each new session.
  config.systemd.user.services.blix-theme = {
    Unit = {
      Description = "Apply the active Blix theme to the session";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${script}/bin/blix-theme apply";
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
