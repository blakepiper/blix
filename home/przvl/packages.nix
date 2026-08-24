{ pkgs, aiUsage, ... }:

{
  home.packages = with pkgs; [
    ripgrep
    fd
    alacritty
    nodejs
    codex
    claude-code
    opencode
    brightnessctl
    hyprsunset
    networkmanagerapplet
    pavucontrol
    wireplumber
    fuzzel
    nautilus
    file-roller
    ffmpegthumbnailer
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
    noto-fonts
    noto-fonts-color-emoji
  ] ++ [
    aiUsage
  ];
}
