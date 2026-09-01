#!/usr/bin/env nu

use source.nu [repo-root stage-source report]

def main [kind: string] {
  let root = (repo-root)
  let staged = (stage-source $root)
  let result = if $kind == "statix" {
    ^statix check $staged | complete
  } else if $kind == "deadnix" {
    ^deadnix --fail $staged | complete
  } else {
    rm --recursive --force $staged
    error make {msg: $"unknown lint kind ($kind)"}
  }
  rm --recursive --force $staged
  report $result
}
