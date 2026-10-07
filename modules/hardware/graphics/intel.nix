{ pkgs, ... }:

{
  # Intel's OpenGL driver does not include its separate VA-API video decoder.
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
}
