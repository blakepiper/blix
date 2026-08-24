# ArchRiot, adapted from https://github.com/CyphrRiot/omarchy-archriot-theme.
#
# The upstream theme ships Omarchy's file layout (waybar.css, walker.css,
# mako.ini, and a bundled wallpaper). Blix drives every application from one
# palette instead, so only the colors are carried over here; the per-app files
# are regenerated from this palette in themes/apps.nix. Upstream's Tokyo Night
# base and its purple/blue accents are preserved exactly.
{
  label = "ArchRiot";
  polarity = "dark";

  wallpaper = ./wallpapers/archriotdefault.png;

  colors = {
    background = "#1a1b26";
    surface = "#222436";
    elevated = "#414868";
    foreground = "#ffffff";
    muted = "#565f89";
    primary = "#bb9af7";
    accent = "#7da6ff";
    border = "#bb9af7";

    black = "#414868";
    red = "#ff7a93";
    green = "#9ece6a";
    yellow = "#e0af68";
    blue = "#7da6ff";
    magenta = "#bb9af7";
    cyan = "#0db9d7";
    white = "#c0caf5";

    brightBlack = "#565f89";
    brightRed = "#ff7a93";
    brightGreen = "#9ece6a";
    brightYellow = "#e0af68";
    brightBlue = "#7da6ff";
    brightMagenta = "#bb9af7";
    brightCyan = "#73daca";
    brightWhite = "#ffffff";
  };
}
