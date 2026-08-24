{ ... }:

{
  users.users.przvl = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
