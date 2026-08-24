{ pkgs, aiUsage, ... }:

# Packages that no program, service, or font module already installs.
# `alacritty` and `fuzzel` come from their programs.* modules, `wireplumber`
# from the system PipeWire module, `neovim` from programs.neovim, and fonts
# from fonts.packages.
{
  home.packages = with pkgs; [
    ripgrep
    fd
    nodejs
    codex
    claude-code
    opencode
    brightnessctl
    hyprsunset
    networkmanagerapplet
    pavucontrol
    nautilus
    file-roller
    ffmpegthumbnailer
    xfce4-genmon-plugin
    vscodium
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
