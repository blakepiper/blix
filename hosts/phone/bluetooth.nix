{ ... }:

{
  # AutoConnect has its own notification, independent of ConnectionNotifier.
  # Honor the phone user's disabled connection popups for reconnects too.
  nixpkgs.overlays = [
    (final: prev: {
      blueman = prev.blueman.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./blueman-autoconnect-notifications.patch ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          ${final.buildPackages.python3.interpreter} ${../../tests/blueman-autoconnect.py} blueman/plugins/applet/AutoConnect.py
          runHook postCheck
        '';
      });
    })
  ];
}
