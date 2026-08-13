let
  schema = import ./schema.nix;
  representation = import ./representation.nix { inherit schema; };
  logismos = import ../logismos;
  levels = import ./levels.nix { inherit representation; };
  traversal = import ./traversal.nix {
    inherit representation levels schema;
    inherit (logismos) computation;
    inherit (logismos) traversal;
  };
  operations = import ./operations.nix { inherit representation traversal; };
  equations = import ./equations.nix;
in
{
  inherit
    schema
    representation
    levels
    traversal
    operations
    equations
    ;
}
