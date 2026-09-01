{ observer, logismos }:
let
  schema = import ./schema.nix;
  representation = import ./representation.nix { inherit schema; };
  levels = import ./levels.nix { inherit representation; };
  traversal = import ./traversal.nix {
    inherit
      representation
      levels
      schema
      observer
      ;
    inherit (logismos) computation traversal;
  };
  operations = import ./operations.nix { inherit representation traversal observer; };
  equations = import ./equations.nix;
  public = {
    inherit
      schema
      representation
      levels
      traversal
      operations
      equations
      ;
  };
in
{
  inherit public;
  components = { inherit traversal operations; };
  wiring.observer = observer.identity;
}
