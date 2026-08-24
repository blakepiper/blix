{ resources, ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "${resources.wallpaper}";
          fit_mode = "cover";
        }
      ];
    };
  };
}
