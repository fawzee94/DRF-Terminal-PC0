# Locale, display server, display manager, window manager, XDG portals,
# and fonts - the visible desktop layer. Shared between both machines.
{ pkgs, lib, unstable, ... }:
{
  # ---- Locale & keyboard -------------------------------------------------
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };
  console.keyMap = "uk";

  # ---- Display server & login --------------------------------------------
  services.xserver.enable = true;

  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "matrix";
      bigclock = true;
      clock = "%c";
      numlock = true;
      hide_version_string = true;
      hide_key_hints = true;
    };
  };

  # ---- Window manager -----------------------------------------------------
  # Mango is shared. Niri is currently laptop-only - see hosts/laptop.nix
  # and the FLAG comment there.
  programs.mangowc = {
    enable = true;
    package = unstable.mango;
  };

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSOR = "1";
    NIXOS_OZONE_WL = "1";
  };

  # ---- XDG portals ---------------------------------------------------------
  # FLAG: your two configs disagreed here - the PC used
  # xdg-desktop-portal-wlr (screencast/screenshot for wlroots compositors)
  # while the laptop used xdg-desktop-portal-gnome. Kept the PC's choice
  # per your "PC wins on conflicts" instruction; say the word if the
  # laptop actually needs the GNOME portal instead.
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk # file picker, settings, print, email
    pkgs.xdg-desktop-portal-wlr # screencast/screenshot for wlroots compositors
  ];

  # Only the PC config had this; added here since it's a small,
  # low-risk addition (keyring secrets service) that benefits both.
  services.gnome.gnome-keyring.enable = true;

  # ---- Fonts ----------------------------------------------------------------
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    fira-code
    fira-code-symbols
    departure-mono
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  fonts.fontconfig = {
    antialias = true;
    hinting = {
      enable = true;
      autohint = true;
    };
    subpixel.rgba = "rgb";
    defaultFonts = {
      emoji = [ "Noto Color Emoji" ];
      monospace = [ "FiraCode Nerd Font" "DejaVu Sans Mono" ];
      sansSerif = [ "Inter" "Noto Sans" ];
    };
  };
}
