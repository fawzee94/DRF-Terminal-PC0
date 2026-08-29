# Given the nixpkgs-unstable flake input, returns a function that builds
# an unstable package set for a given `system` string, with unfree
# packages allowed. Used once in flake.nix to produce the `unstable`
# specialArg that every host and module can reach (e.g. `unstable.mango`).
{ nixpkgs-unstable }:
system:
import nixpkgs-unstable {
  inherit system;
  config.allowUnfree = true;
}
