{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    # Match Blix's managed Firefox profile: uBlock Origin, Dark Reader,
    # Enhancer for YouTube, strict tracking protection, Global Privacy
    # Control, no sponsored/recommended content, and Firefox AI features
    # blocked by default.
    policies = {
      FirefoxHome = {
        SponsoredTopSites = false;
        Stories = false;
        SponsoredStories = false;
      };

      FirefoxSuggest.SponsoredSuggestions = false;

      EnableTrackingProtection = {
        Value = true;
        Category = "strict";
      };

      Preferences."privacy.globalprivacycontrol.enabled" = {
        Value = true;
        Status = "user";
      };

      AIControls.Default = {
        Value = "blocked";
        Locked = true;
      };

      ExtensionSettings."uBlock0@raymondhill.net" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        installation_mode = "force_installed";
        private_browsing = true;
      };

      ExtensionSettings."addon@darkreader.org" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
        installation_mode = "force_installed";
        private_browsing = true;
      };

      ExtensionSettings."enhancerforyoutube@maximerf.addons.mozilla.org" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/enhancer-for-youtube/latest.xpi";
        installation_mode = "force_installed";
        private_browsing = true;
      };
    };
  };
}
