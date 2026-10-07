{ config, lib, pkgs, ... }:

let
  navbar = [
    "reset-pbm-toolbar-button"
    "unified-extensions-button"
    "urlbar-container"
    "back-button"
    "forward-button"
    "stop-reload-button"
    "vertical-spacer"
    "smartwindow-group-tabs-button"
    "ai-window-toggle"
  ];
  tabstrip = [
    "tabbrowser-tabs"
    "customizableui-special-spring1"
    "smartwindow-group-tabs-button"
    "ai-window-toggle"
  ];
  extensions = [
    "addon_darkreader_org-browser-action"
    "enhancerforyoutube_maximerf_addons_mozilla_org-browser-action"
    "ublock0_raymondhill_net-browser-action"
  ];
in

{
  home.sessionVariables.BROWSER = lib.getExe config.programs.firefox.finalPackage;

  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    policies = (builtins.fromJSON (builtins.readFile ../config/firefox/policies.json)).policies;

    profiles.default = {
      id = 0;
      isDefault = true;
      extraConfig = builtins.readFile ../config/firefox/user.js;
      userChrome = ../config/firefox/chrome/userChrome.css;
      settings = {
        "browser.uiCustomization.navBarWhenVerticalTabs" = builtins.toJSON navbar;
        "browser.uiCustomization.horizontalTabstrip" = builtins.toJSON tabstrip;
        "browser.uiCustomization.state" = builtins.toJSON {
          placements = {
            "widget-overflow-fixed-list" = [ ];
            "unified-extensions-area" = extensions;
            "nav-bar" = navbar;
            "toolbar-menubar" = [ "menubar-items" ];
            "TabsToolbar" = [ ];
            "vertical-tabs" = [ "tabbrowser-tabs" ];
            "PersonalToolbar" = [ "import-button" "personal-bookmarks" ];
          };
          seen = extensions ++ [ "reset-pbm-toolbar-button" "developer-button" "screenshot-button" ];
          dirtyAreaCache = [ "nav-bar" "TabsToolbar" "vertical-tabs" "PersonalToolbar" "unified-extensions-area" "toolbar-menubar" ];
          currentVersion = 26;
          newElementCount = 1;
        };
      };
    };
  };
}
