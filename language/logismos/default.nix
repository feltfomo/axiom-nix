let
  computation = import ./computation.nix;
  transition = import ./transition.nix;
  relation = import ./relation.nix { inherit computation; };
  traversal = import ./traversal.nix { inherit computation transition; };
  budget = import ./budget.nix { inherit computation; };
in
{
  inherit
    computation
    relation
    transition
    traversal
    budget
    ;
}
