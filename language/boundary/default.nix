let
  logismos = import ../logismos;
  result = import ./result.nix;
  budget = import ./budget.nix { inherit result logismos; };
  policy = import ./policy.nix {
    inherit result budget logismos;
  };
  observe = import ./observe.nix {
    inherit
      result
      policy
      budget
      logismos
      ;
  };
  deep = import ./deep.nix {
    inherit
      result
      policy
      budget
      observe
      logismos
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
