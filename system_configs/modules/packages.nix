# Shared system packages and enabled programs.
#
# Host-only extras (e.g. the laptop's niri-specific tools) are appended
# in that host's file - environment.systemPackages is a list option, so
# NixOS concatenates every module's list rather than one overriding
# another.
{ pkgs, unstable, ... }:
{
  nixpkgs.config.allowUnfree = true;

  programs.starship.enable = true;
  programs.nm-applet.enable = true;
  programs.seahorse.enable = true;
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    # ---- Libs & utils ----
    glib
    lshw
    lsof
    ntfs3g
    exfat
    exfatprogs
    pciutils
    libnotify
    wget
    usbutils
    gparted
    stow
    pavucontrol
    unrar

    # ---- DE components ----
    unstable.mango
    networkmanagerapplet
    rofi
    wl-clipboard
    cliphist
    unstable.waybar
    swaynotificationcenter
    swayidle
    swaylock-effects
    awww
    waypaper
    pasystray
    nwg-look
    wl-color-picker
    font-manager
    dconf-editor
    unstable.quickshell

    # ---- Terminal ----
    unstable.ghostty
    micro
    yazi
    btop-cuda
    tealdeer
    fastfetch
    figlet
    fzf
    git

    # ---- Basic apps ----
    nautilus
    file-roller
    gedit
    lite-xl
    geany
    vivaldi
    brave
    nomacs
    vlc

    # ---- Workstation ----
    drawy
    onlyoffice-desktopeditors
    krita
    unstable.godot
    video-trimmer

    # ---- Other ----
    transmission_4-gtk
    blanket
    prismlauncher
    unstable.freetube
    espanso-wayland
  ];
}
