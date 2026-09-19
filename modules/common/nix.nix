{ pkgs, ... }:

{
  # nixpkgs currently defaults to 2.34.x; use the newest Nix package carried
  # by the refreshed input when this system is rebuilt.
  nix.package = pkgs.nixVersions.latest;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.optimise.automatic = true;
}
