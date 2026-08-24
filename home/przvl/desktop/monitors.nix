# Per-host monitor layout.
#
# The monitor layout is the one part of the przvl desktop that depends on the
# physical machine, so hosts declare it rather than home/przvl/. Each host sets
# blix.monitors in its hosts/<hostname>/home.nix; desktop/hyprland.nix renders
# the list into the Hyprland Lua configuration.
{ lib, ... }:

{
  options.blix.monitors = lib.mkOption {
    default = [ ];
    description = "Hyprland monitor layout for this host, in declaration order.";
    example = [
      {
        output = "eDP-1";
        mode = "1920x1080@60";
        position = "0x0";
        scale = 1.0;
      }
    ];
    type = lib.types.listOf (lib.types.submodule {
      options = {
        output = lib.mkOption {
          type = lib.types.str;
          description = "Connector name, as reported by `hyprctl monitors`.";
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "preferred";
          description = "Resolution and refresh rate, for example \"1920x1080@60\".";
        };
        position = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = "Layout position, for example \"0x0\".";
        };
        scale = lib.mkOption {
          type = lib.types.number;
          default = 1;
          description = "Fractional scale factor.";
        };
      };
    });
  };
}
