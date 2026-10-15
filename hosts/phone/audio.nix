# The pinned SDM845 UCM package covers enchilada, but not fajita's TFA9894.
{ pkgs, ... }:

{
  # Meld these non-conflicting files with the upstream UCM tree. Keep the
  # verified speaker route local rather than selecting untested call/mic routes.
  environment.systemPackages = with pkgs; [
    (runCommand "oneplus-fajita-alsa-ucm" { } ''
      mkdir -p "$out/share/alsa"
      cp -r ${./ucm2} "$out/share/alsa/ucm2"
    '')
  ];

  services.pipewire.wireplumber.extraConfig."51-phone-audio" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.platform-snd_aloop.0"; } ];
        actions.update-props."device.disabled" = true;
      }
    ];
  };
}
