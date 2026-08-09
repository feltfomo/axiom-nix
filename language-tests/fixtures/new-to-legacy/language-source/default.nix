let
  sentinel = "${toString ./.}/../legacy-target/legacy-sentinel.nix";
in
if builtins.pathExists sentinel then import sentinel else throw "legacy sentinel absent"
