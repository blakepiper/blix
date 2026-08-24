{ pkgs, ... }:

{
  programs.hyprland.enable = true;

  # Start a login prompt at boot, then launch Hyprland after authentication.
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd ${pkgs.hyprland}/bin/start-hyprland";
      user = "greeter";
    };
  };

  security.pam.services.hyprlock = { };
}
