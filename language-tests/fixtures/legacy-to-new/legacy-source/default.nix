let
  sentinel = "${toString ./.}/../language-target/language-sentinel.nix";
in
if builtins.pathExists sentinel then import sentinel else throw "language sentinel absent"
