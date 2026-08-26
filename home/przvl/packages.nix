{ pkgs, aiUsage, ... }:

# Packages that no program, service, or font module already installs.
# `alacritty` and `fuzzel` come from their programs.* modules, `wireplumber`
# from the system PipeWire module, `gammastep` from the night-mode service,
# and fonts from fonts.packages.
{
  home.packages = with pkgs; [
    ripgrep
    fd
    nodejs
    codex
    claude-code
    opencode
    brightnessctl
    networkmanagerapplet
    pavucontrol
    nautilus
    file-roller
    ffmpegthumbnailer
    python3
    uv
    fastfetch
    btop
    grim
    slurp
    wl-clipboard
    zip
    unzip
    p7zip
    blesh
  ] ++ [
    aiUsage
  ];
}
