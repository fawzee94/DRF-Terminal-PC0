# Shared module list. Imported by both hosts (see flake.nix). Each host
# then layers its own machine-specific file (hosts/desktop.nix or
# hosts/laptop.nix) and its own hardware-configuration.nix on top - those
# are added directly in flake.nix, not imported here.
{ ... }:
{
  imports = [
    ./modules/bootloader.nix
    ./modules/networking.nix
    ./modules/desktop-environment.nix
    ./modules/services.nix
    ./modules/packages.nix
    ./modules/misc.nix
  ];
}
