{ lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;

    # Fast autorepeat for editing and navigation keys such as Backspace and
    # the arrow keys: 200 ms initial delay, then 50 repeats per second.
    autoRepeatDelay = 200;
    autoRepeatInterval = 20;

    # Blix starts one X11 session manually from a TTY. The Home Manager
    # configuration supplies ~/.xinitrc, so NixOS only needs to install xinit
    # and expose OXWM as the available window manager.
    displayManager.startx = {
      enable = true;
      generateScript = false;
    };

    windowManager.oxwm = {
      enable = true;
      package = pkgs.oxwm;
    };

    xkb.layout = "us";
  };

  services.libinput = {
    enable = true;
    touchpad = {
      clickMethod = "clickfinger";
      naturalScrolling = true;
      tapping = true;
      tappingButtonMap = "lrm";
      disableWhileTyping = true;
    };
  };

  # Match Blix's mouse classification: touchpads, tablets, and pointing
  # sticks are excluded; only ordinary pointer devices get natural scrolling.
  # Keep this after NixOS's generic libinput mouse section: Xorg applies the
  # later matching option, so this keeps the targeted value from being reset.
  services.xserver.inputClassSections = lib.mkAfter [
    ''
      Identifier "Blix mice (not pointing sticks)"
      MatchIsPointer "on"
      MatchIsTouchpad "off"
      MatchDriver "libinput"
      MatchTag "blix-mouse"
      Option "NaturalScrolling" "true"
    ''
  ];

  services.udev.extraRules = ''
    ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", ENV{ID_INPUT_POINTINGSTICK}!="1", ENV{ID_INPUT_TOUCHPAD}!="1", ENV{ID_INPUT_TABLET}!="1", ENV{ID_INPUT.tags}="$env{ID_INPUT.tags},blix-mouse"
  '';
}
