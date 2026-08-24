{ ... }:

{
  # Keep Xfce's libinput behavior aligned with the shared Hyprland input
  # settings without naming a particular machine's touchpad.
  services.libinput.touchpad = {
    clickMethod = "clickfinger";
    naturalScrolling = true;
    tapping = true;
    tappingButtonMap = "lrm";
  };
}
