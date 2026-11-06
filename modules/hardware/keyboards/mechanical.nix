{ ... }:

{
  # This keyboard's Mac mode puts Cmd in the Alt position. Remap its USB
  # scancodes before X11/Wayland so both sessions agree without a global swap.
  services.udev.extraHwdb = ''
    evdev:input:b0003v1FC9pE8C7*
     KEYBOARD_KEY_700e2=leftmeta
     KEYBOARD_KEY_700e3=leftalt
     KEYBOARD_KEY_700e6=rightmeta
     KEYBOARD_KEY_700e7=rightalt
  '';
}
