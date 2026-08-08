{
  description = "validation, schema, registry, and phase primitives for nix config libraries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # axiom takes a lib and hands back attrs, so consumers apply it against
      # their own lib instead of reading a per-system output.
      flake.lib.axiom = import ./src;

      perSystem =
        { pkgs, ... }:
        {
          treefmt = import ./formatter.nix;

          # the suite throws on the first failing case, so evaluating .ok is the
          # whole check and the assert keeps that throw at build time.
          checks.tests = pkgs.runCommandLocal "axiom-tests" { } (
            assert (import ./tests { inherit (pkgs) lib; }).ok;
            "touch $out"
          );

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt-rfc-style
              pkgs.statix
            ];
          };
        };
    };
}
