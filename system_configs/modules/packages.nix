# Shared system packages and enabled programs.
#
# Host-only extras (e.g. the laptop's niri-specific tools) are appended
# in that host's file - environment.systemPackages is a list option, so
# NixOS concatenates every module's list rather than one overriding
# another.
{ pkgs, unstable, ... }:
{
  nixpkgs.config.allowUnfree = true;

  # Terminal promt ricer
  programs.starship.enable = true;
  # Network applet
  programs.nm-applet.enable = true;
  # Authentication GUI
  programs.seahorse.enable = true;
  # Game launcher/cathalog
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    # ---- Libs & utils ----
    # Low-level library
    glib
    # List hardware
    lshw
    # List open files
    lsof
    # NTFS read/write
    ntfs3g
    # exFAT support
    exfat
    exfatprogs
    # PCI inspector
    pciutils
    # Notification library
    libnotify
    # HTTP/FTP downloader
    wget
    # USB inspector
    usbutils
    # Disk editor
    gparted
    # Symlink farm manager
    stow
    # Pipewiire/PulseAudio Gui mixer
    pavucontrol
    # RAR extraction backend
    unrar

    # ---- DE components ----
    # Launcher
    rofi
    # Clipboard
    wl-clipboard
    cliphist
    # System bar
    unstable.waybar
    # Notification
    swaynotificationcenter
    # Screen lock
    swayidle
    swaylock-effects
    # Wallpaper manager
    awww
    waypaper
    # Audio tray applet
    pasystray
    # Settings/Themes
    nwg-look
    font-manager
    dconf-editor
    # Color picker
    wl-color-picker
    # Custom desktop components
    unstable.quickshell

    # ---- Terminal ----
    # Terminal emulator
    unstable.ghostty
    # Text editor
    micro
    # File browser
    yazi
    # System monitor
    btop-cuda
    # Community-driven man pages
    tealdeer
    # System info
    fastfetch
    # Ascii fonts
    figlet
    # fuzzy search
    fzf
    # Version control
    git

    # ---- Basic apps ----
    # File browser
    nautilus
    # Archive manager
    file-roller
    # Text editor
    gedit
    geany
    # Browser
    vivaldi
    brave
    # Image Viewer
    nomacs
    # Video player
    vlc

    # ---- Workstation ----
    # Drawing board
    drawy
    # Office
    onlyoffice-desktopeditors
    # Digital drawing
    krita
    # Game engine
    unstable.godot
    # Video editing
    video-trimmer
    # AI
    claude-code

    # ---- Other ----
    # Torrent client
    transmission_4-gtk
    # Ambient sound player
    blanket
    # Minecraft launcher
    prismlauncher
    # Youtube Client
    unstable.freetube
  ];
}
