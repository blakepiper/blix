# Shared user identity and capabilities, with no desktop or application policy.
{ ... }:

{
  imports = [ ./hardware ];

  home = {
    username = "przvl";
    homeDirectory = "/home/przvl";
    stateVersion = "26.05";
  };
}
