{ core }:
let
  observation = import ../internal/operation-observer.nix;
  logismos = import ../logismos;
  evaluation = import ../evaluation { inherit core; };
in
(import ./construct.nix {
  inherit core evaluation logismos;
  observer = observation.silent;
}).public
