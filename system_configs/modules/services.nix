# Background services shared between both machines: audio, and the
# per-user session daemons for wallpaper/idle handling.
#
# Bluetooth is deliberately NOT here - only the laptop has Bluetooth
# hardware, so it's defined in hosts/laptop.nix instead.
{ pkgs, ... }:
{
  # ---- Audio (Pipewire) ----------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  
  # ---- Text expander ----------------------------------------------------
  services.espanso = {
    enable = true;
    package = espanso-wayland;
  };
  # ---- Per-session daemons --------------------------------------------------
  # swww (wallpaper daemon) and swayidle (idle/lock handling) are shared.
  # xwayland-satellite was only in the laptop config; since niri is
  # currently laptop-only too (see hosts/laptop.nix), that service moved
  # there with it rather than being forced onto the desktop.
  systemd.user.services = {
    awww = {
      description = "Background service";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
    };

    swayidle = {
      path = with pkgs; [ swaylock-effects niri ];
      description = "Idle Service";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.swayidle}/bin/swayidle -w timeout 420 'systemctl suspend' timeout 300 'swaylock -f' before-sleep 'swaylock -f'";
        Restart = "on-failure";
      };
    };
  };
  security.pam.services.ly.enableGnomeKeyring = true;
  security.pam.services.swaylock.enableGnomeKeyring = true;
}
