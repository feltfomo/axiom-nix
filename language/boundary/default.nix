let
  result = import ./result.nix;
  budget = import ./budget.nix { inherit result; };
  policy = import ./policy.nix { inherit result budget; };
  observe = import ./observe.nix {
    inherit result policy budget;
  };
  deep = import ./deep.nix {
    inherit
      result
      policy
      budget
      observe
      ;
  };
in
{
  budgets = budget.names;
  inherit (policy)
    categories
    policies
    validatePolicy
    validatePlan
    ;
  result = {
    inherit (result)
      codes
      success
      mismatch
      hostFailure
      exhausted
      internalBug
      isResult
      ;
  };
  observeOpaque = observe.opaque;
  observeOuter = observe.outer;
  observeSpine = observe.spine;
  observeFields = observe.fields;
  observeDeep = deep.run;
  inherit (observe) invoke;
}
