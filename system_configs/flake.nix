{
  description = "FWZ's NixOS Flake Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
    let
      system = "x86_64-linux";

      # Small helper (flake-modules/channels.nix) that builds an
      # "unstable" package set for a given system, with unfree allowed.
      # This is what lets any module reach e.g. `unstable.mango`.
      mkUnstable = import ./flake_modules/channels.nix { inherit nixpkgs-unstable; };
      unstable = mkUnstable system;
    in {
      nixosConfigurations = {

        # Desktop tower: single dedicated Nvidia GPU, no hybrid graphics,
        # no Bluetooth hardware.
        "DRF-terminal-PC0" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs unstable; };
          modules = [
            ./configuration.nix
            ./hosts/PC0.nix
            # Real, machine-generated file - lives untouched in /etc/nixos
            # on each machine, never tracked in the dotfiles repo.
            /etc/nixos/hardware-configuration.nix
          ];
        };

        # Laptop: Intel/Nvidia Optimus hybrid graphics, onboard Bluetooth.
        "DRF-terminal-LT0" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs unstable; };
          modules = [
            ./configuration.nix
            ./hosts/LT0.nix
            /etc/nixos/hardware-configuration.nix
          ];
        };
      };
    };
}
