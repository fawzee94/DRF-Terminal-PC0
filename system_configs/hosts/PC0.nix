# DRF-terminal-PC0 - desktop tower.
#
# Single dedicated Nvidia GPU (no hybrid/Optimus switching), no
# Bluetooth hardware, and a USB-C dock/controller quirk that needs a
# kernel workaround.
{ config, pkgs, ... }:
{
  networking.hostName = "DRF-terminal-PC0";

  # Desktop-only kernel workaround for a flaky USB-C controller.
  # Merges into modules/bootloader.nix's kernelParams list.
  boot.kernelParams = [ "ucsi_ccg.ignore=1" ];

  # Minecraft server port - only opened on the desktop.
  networking.firewall.allowedTCPPorts = [ 25565 ];

  # ---- GPU: single Nvidia card, no hybrid switching ------------------------
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    # No `package` pin - tracks whatever driver the current nixpkgs
    # channel ships by default. Pin it here if you need a specific
    # version again.
  };

  hardware.opentabletdriver.enable = true;
  
  # ---- Machine exclusive packages --------------------------------------
  environment.systemPackages = with pkgs; [
    # Font editor
    fontforge-gtk
  ];
  
  # NixOS version at the time of install for legacy support purposes
  # after updates- only bump it if you've read the release notes for
  # the version jump and are sure.
  system.stateVersion = "25.05";
}
