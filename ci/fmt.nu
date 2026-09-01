#!/usr/bin/env nu

use source.nu [repo-root source-paths stage-source report]

def check-format [root: path] {
  let staged = (stage-source $root)
  let formatted = (^treefmt --config-file ($staged | path join "treefmt.toml") --tree-root $staged --walk filesystem --no-cache | complete)
  mut differences = []
  if $formatted.exit_code == 0 {
    for relative in (source-paths) {
      let original = ($root | path join $relative)
      let candidate = ($staged | path join $relative)
      if ($original | path exists) and ($candidate | path exists) {
        let compared = (^diff --recursive --brief $original $candidate | complete)
        if $compared.exit_code == 1 {
          $differences = ($differences | append $compared.stdout)
        } else if $compared.exit_code > 1 {
          rm --recursive --force $staged
          report $compared
        }
      }
    }
  }
  rm --recursive --force $staged
  report $formatted
  if ($differences | is-not-empty) {
    $differences | each {|difference| print --stderr $difference }
    exit 1
  }
}


def main [--check] {
  let root = (repo-root)
  if $check {
    check-format $root
  } else {
    report (^treefmt --config-file ($root | path join "treefmt.toml") --tree-root $root | complete)
  }
}
