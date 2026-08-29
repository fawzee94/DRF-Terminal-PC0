# Everything that didn't earn its own module: user account, removable
# media handling, printing, and Nix's own housekeeping.
{ ... }:
{
  # ---- User account ----------------------------------------------------
  users.users.fwz = {
    isNormalUser = true;
    description = "fwz";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = [ ];
  };

  # ---- Removable media / USB --------------------------------------------
  services.devmon.enable = true;
  services.gvfs.enable = true;
  services.udisks2 = {
    enable = true;
    settings = {
      "mount_options.conf" = {
        defaults = {
          ntfs_defaults = "uid=$UID,gid=$GID,windows_names,remove_hiberfile";
        };
      };
    };
  };

  # ---- Printing -----------------------------------------------------------
  services.printing.enable = true;

  # ---- Nix housekeeping -----------------------------------------------------
  nix.gc = {
    automatic = true;
    dates = "03:00";
    options = "--delete-older-than 7d";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "04:00" ];
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
