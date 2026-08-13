let
  stack = import ./stack.nix;
  computation = import ./computation.nix { inherit stack; };
  transition = import ./transition.nix { inherit stack; };
  relation = import ./relation.nix { inherit computation; };
  traversal = import ./traversal.nix { inherit computation transition stack; };
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
