{ ... }:

{
  # Hyprland configures its own libinput devices; this is the X11 driver's
  # configuration, which now applies only to SDDM's greeter. Keep the greeter's
  # touchpad behaving like the desktop's.
  services.libinput.touchpad = {
    clickMethod = "clickfinger";
    naturalScrolling = true;
    tapping = true;
    tappingButtonMap = "lrm";
  };
}
