let
  observation = import ../internal/operation-observer.nix;
  constructed = import ./construct.nix {
    observer = observation.silent;
    logismos = import ../logismos;
  };
in
constructed.public
