let
  observation = import ../internal/operation-observer.nix;
in
(import ./construct.nix { observer = observation.silent; }).public
