{ core }:
let
  logismos = import ../logismos;
  representation = import ./representation.nix;
  schema = import ./schema.nix;
  result = import ./result.nix;
  budget = import ./budget.nix { inherit result logismos; };
  direct = import ./direct.nix {
    inherit
      core
      representation
      result
      budget
      logismos
      ;
  };
  machine = import ./machine.nix {
    inherit
      core
      representation
      result
      budget
      logismos
      ;
  };
in
{
  inherit
    representation
    schema
    result
    direct
    machine
    ;
}
