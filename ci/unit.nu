#!/usr/bin/env nu

use source.nu [repo-root stage-source report]

def main [] {
  let root = (repo-root)
  let staged = (stage-source $root)
  let result = (^nix-unit --option extra-experimental-features "nix-command flakes pipe-operators" --flake $"path:($staged)#tests" | complete)
  rm --recursive --force $staged
  report $result
}
