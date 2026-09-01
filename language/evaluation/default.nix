{ core }:
let
  observation = import ../internal/operation-observer.nix;
  constructed = import ./construct.nix {
    inherit core;
    observer = observation.silent;
    logismos = import ../logismos;
  };
in
constructed.public
