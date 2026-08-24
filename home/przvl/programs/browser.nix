{ ... }:

{
  programs.firefox = {
    enable = true;

    # No profile is declared here on purpose. Firefox creates its own profile
    # with a generated name, and blix-theme links the active theme's user.js
    # into whichever profiles exist; see themes/blix-theme.sh.
    policies.ExtensionSettings."uBlock0@raymondhill.net" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      installation_mode = "force_installed";
      private_browsing = true;
    };
  };
}
