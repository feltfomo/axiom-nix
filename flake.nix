{
  description = "functional machinery and a typed language layer for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    inputs@{ nixpkgs, ... }:
    {
      lib = {
        axiom = import ./src;
        axiomLanguage = import ./language;
      };

      tests = import ./unit-tests.nix {
        inherit inputs;
        inherit (nixpkgs) lib;
      };
    };
}
