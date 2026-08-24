{ theme, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };
      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }
      ];
      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(${theme.rgb.foreground})";
          font_size = 72;
          font_family = theme.font;
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
      ];
      "input-field" = [
        {
          size = "240, 54";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(${theme.rgb.foreground})";
          inner_color = "rgba(${theme.rgb.background}aa)";
          outer_color = "rgb(${theme.rgb.border})";
          outline_thickness = 3;
          placeholder_text = "";
        }
      ];
    };
  };
}
