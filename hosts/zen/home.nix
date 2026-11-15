# ASUS Zenbook — przvl Home Manager configuration specific to this machine.
#
# The laptop profile supplies the shared workstation user configuration.
{ ... }:

{
  imports = [ ./display.nix ../../home/przvl/programs/steam.nix ];

  # Suppress Ghostty's transient size overlay when Hyprland places new windows.
  programs.ghostty.settings.resize-overlay = "never";

  blix.hyprland.retroTerminalSize = 15;
}
