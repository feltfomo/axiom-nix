{
  core,
  logismos,
  observer,
}:
let
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
      observer
      ;
  };
  machine = import ./machine.nix {
    inherit
      core
      representation
      result
      budget
      logismos
      observer
      ;
  };
  public = {
    inherit
      representation
      schema
      result
      direct
      machine
      ;
  };
in
{
  inherit public;
  components = { inherit direct machine; };
  wiring = {
    observer = observer.identity;
    core = core.representation.generation;
  };
}
