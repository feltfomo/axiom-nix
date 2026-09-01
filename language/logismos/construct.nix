{ observer }:
let
  stack = import ./stack.nix;
  computation = import ./computation.nix { inherit stack observer; };
  transition = import ./transition.nix { inherit stack observer; };
  relation = import ./relation.nix { inherit computation; };
  traversal = import ./traversal.nix { inherit computation transition stack; };
  budget = import ./budget.nix { inherit computation; };
  public = {
    inherit
      computation
      relation
      transition
      traversal
      budget
      ;
  };
in
{
  inherit public;
  components = { inherit computation transition; };
  wiring.observer = observer.identity;
}
