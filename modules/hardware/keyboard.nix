{ ... }:

{
  imports = [ ./keyboards/mechanical.nix ];

  services.xserver = {
    xkb.layout = "us";
    # 200 ms initial delay, then 50 repeats per second.
    autoRepeatDelay = 200;
    autoRepeatInterval = 20;
  };
}
