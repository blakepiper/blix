# XRandR verified DSI-1, 1080x2340 at 60 Hz; use it sideways with the keyboard.
{ ... }:

{
  blix.display = {
    primaryOutput = "DSI-1";
    primaryRotation = "left";
    # Twice the observed 96 DPI baseline; keep the native panel resolution.
    dpi = 192;
    wallpaper = "/home/przvl/Pictures/forest.jpg";
  };
}
