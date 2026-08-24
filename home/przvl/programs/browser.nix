{ ... }:

{
  programs.firefox = {
    enable = true;

    policies = {
      # Remove the old per-theme user.js overrides. Firefox can then follow the
      # desktop portal's live color-scheme signal in both desktop sessions.
      Preferences = {
        "ui.systemUsesDarkTheme" = {
          Value = 0;
          Status = "clear";
          Type = "number";
        };
        "browser.theme.toolbar-theme" = {
          Value = 2;
          Status = "clear";
          Type = "number";
        };
        "browser.theme.content-theme" = {
          Value = 2;
          Status = "clear";
          Type = "number";
        };
      };

      ExtensionSettings."uBlock0@raymondhill.net" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        installation_mode = "force_installed";
        private_browsing = true;
      };
    };
  };
}
