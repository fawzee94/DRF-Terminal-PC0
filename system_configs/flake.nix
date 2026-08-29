{
  description = "FWZ's NixOS Flake Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
    let
      system = "x86_64-linux";
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations."DRF-terminal-PC0" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs unstable; };
        modules = [
          ./configuration.nix
        ];
      };
    };
}
