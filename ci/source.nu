export def repo-root [] {
  mut current = ($env.PWD | path expand)
  loop {
    let has_devenv = (($current | path join "devenv.nix") | path exists)
    let has_flake = (($current | path join "flake.nix") | path exists)
    if $has_devenv and $has_flake {
      return $current
    }
    let parent = ($current | path dirname)
    if $parent == $current {
      error make {msg: "could not find repository root"}
    }
    $current = $parent
  }
}

export def source-paths [] {
  [
    ".envrc"
    ".github"
    ".gitignore"
    "ci"
    "devenv.lock"
    "devenv.nix"
    "devenv.yaml"

    "docs"
    "flake.lock"
    "flake.nix"
    "language"
    "language-tests"
    "src"
    "tests"
    "treefmt.toml"
    "unit-tests.nix"
  ]
}

export def stage-source [root: path] {
  let made = (^mktemp --directory | complete)
  if $made.exit_code != 0 {
    error make {msg: $made.stderr}
  }
  let target = ($made.stdout | str trim)
  for relative in (source-paths) {
    let source = ($root | path join $relative)
    if ($source | path exists) {
      let destination = ($target | path join $relative)
      mkdir ($destination | path dirname)
      cp --recursive $source $destination
    }
  }
  $target
}

export def report [result: record] {
  if ($result.stdout | str length) > 0 {
    print $result.stdout
  }
  if ($result.stderr | str length) > 0 {
    print --stderr $result.stderr
  }
  if $result.exit_code != 0 {
    exit $result.exit_code
  }
}
