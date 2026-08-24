# Facts about the machine this user configuration is running on.
#
# Hosts supply these: `blix.formFactor` is mirrored down from the system
# configuration by modules/common.nix, and `blix.monitors` is declared in
# hosts/<hostname>/home.nix. Shared user configuration reads these options
# instead of branching on the hostname.
{ lib, ... }:

{
  options.blix = {
    formFactor = lib.mkOption {
      type = lib.types.enum [ "laptop" "desktop" ];
      description = ''
        What kind of machine this host is. Set from the host's
        `blix.formFactor`; laptops gain battery-dependent user configuration.
      '';
      example = "laptop";
    };

    monitors = lib.mkOption {
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
  };
}
