{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    policies = (builtins.fromJSON (builtins.readFile ../config/firefox/policies.json)).policies;

    profiles.default = {
      id = 0;
      isDefault = true;
      extraConfig = builtins.readFile ../config/firefox/user.js;
      userChrome = ../config/firefox/chrome/userChrome.css;
    };
  };
}
