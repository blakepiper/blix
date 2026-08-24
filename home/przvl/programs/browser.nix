{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;

    # The default Firefox theme is the one that follows the desktop portal.
    # Use Firefox's Add-on Manager so existing profiles are migrated cleanly
    # from an explicitly selected Light or Dark theme.
    package = pkgs.firefox.override {
      extraPrefs = ''
        Services.obs.addObserver(function enableBlixFirefoxTheme() {
          Services.obs.removeObserver(
            enableBlixFirefoxTheme,
            "browser-delayed-startup-finished"
          );
          const { AddonManager } = ChromeUtils.importESModule(
            "resource://gre/modules/AddonManager.sys.mjs"
          );
          AddonManager.getAddonByID("default-theme@mozilla.org")
            .then(theme => {
              if (theme && !theme.isActive) {
                return theme.enable();
              }
            })
            .catch(Cu.reportError);
        }, "browser-delayed-startup-finished");
      '';
    };

    policies = {
      # Remove the old per-theme user.js overrides. Firefox can then follow the
      # desktop portal's live color-scheme signal in both desktop sessions.
      Preferences = {
        "ui.systemUsesDarkTheme" = {
          Value = 0;
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
